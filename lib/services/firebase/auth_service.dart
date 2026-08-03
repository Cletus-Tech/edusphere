import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/result.dart';
import '../../models/user_model.dart';
import '../audit/audit_log_service.dart';
import 'firestore_service.dart';

/// All authentication flows for EduSphere. Every public method returns a
/// [Result] — UI code should never need a try/catch around a call here.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirestoreService _firestoreService = FirestoreService();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<Result<User>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user == null) {
        AuditLogService.instance.logFailedLogin(email: email.trim());
        return const Result.failure('Login failed. Please try again.');
      }
      await ensureUserProfile(credential.user!);
      AuditLogService.instance.logLogin(uid: credential.user!.uid);
      return Result.success(credential.user!);
    } catch (e) {
      // Stage 3.6.2 Part 2 — audit every failed sign-in. Per
      // `firestore.rules`, this write only succeeds while some session
      // is signed in (a wrong password on an already-authed device,
      // etc.) — a fully unauthenticated attempt is silently dropped by
      // AuditLogService's own error-safety, not a bug here.
      AuditLogService.instance.logFailedLogin(email: email.trim());
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<Result<User>> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return const Result.failure('Registration failed. Please try again.');
      }
      await user.updateDisplayName(fullName);

      final profile = UserModel(
        uid: user.uid,
        fullName: fullName,
        email: email.trim(),
        createdAt: DateTime.now(),
      );
      final profileResult = await _firestoreService.set(
        collection: AppConstants.usersCollection,
        docId: user.uid,
        data: profile.toMap(),
      );
      if (profileResult case Failure(:final message)) {
        // The Auth account exists but the Firestore profile our security
        // rules depend on (notSuspended(), hasRole(), etc.) doesn't. Don't
        // report success — the account is unusable until this exists.
        // ensureUserProfile() below will retry this on next sign-in.
        return Result.failure(
          'Account created, but setting up your profile failed: $message',
        );
      }

      return Result.success(user);
    } catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  /// Self-heals accounts whose Firestore `users/{uid}` profile is missing
  /// (e.g. accounts created before this check existed, or where an earlier
  /// registration attempt's profile write silently failed). Nearly every
  /// Firestore read rule depends on this document existing — without it,
  /// users see permission-denied on things they should be able to read.
  /// Safe to call on every sign-in: a no-op once the profile exists.
  Future<void> ensureUserProfile(User user) async {
    final existing = await _firestoreService.getDoc(
      collection: AppConstants.usersCollection,
      docId: user.uid,
    );
    if (existing case Success(:final data) when data != null) return;

    final profile = UserModel(
      uid: user.uid,
      fullName: user.displayName ?? '',
      email: user.email ?? '',
      createdAt: DateTime.now(),
    );
    await _firestoreService.set(
      collection: AppConstants.usersCollection,
      docId: user.uid,
      data: profile.toMap(),
    );
  }

  Future<Result<User>> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const Result.failure('Google sign-in was cancelled.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        return const Result.failure('Google sign-in failed.');
      }

      // Create a Firestore profile the first time this Google user signs in.
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        final profile = UserModel(
          uid: user.uid,
          fullName: user.displayName ?? '',
          email: user.email ?? '',
          photoUrl: user.photoURL,
          createdAt: DateTime.now(),
        );
        await _firestoreService.set(
          collection: AppConstants.usersCollection,
          docId: user.uid,
          data: profile.toMap(),
        );
      }

      AuditLogService.instance.logLogin(uid: user.uid);
      return Result.success(user);
    } catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<Result<void>> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      // Only attributable if some session happens to be signed in when
      // this is requested (e.g. from an in-app "change email" flow) —
      // the common "forgot password" case is unauthenticated, so this
      // is best-effort per AuditLogService's own error-safety rules.
      final uid = currentUser?.uid;
      if (uid != null) {
        AuditLogService.instance.logPasswordResetRequested(uid: uid, email: email.trim());
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  /// Stage 3.6.2 Part 2 addition — changes the signed-in user's password,
  /// re-authenticating first since Firebase requires a recent sign-in for
  /// this operation. Never logs the password itself, only that a change
  /// happened.
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return const Result.failure('You need to be signed in to change your password.');
    }
    try {
      final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      AuditLogService.instance.logPasswordChanged(uid: user.uid);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<void> signOut() async {
    final uid = currentUser?.uid;
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
    if (uid != null) AuditLogService.instance.logLogout(uid: uid);
  }
}      // is signed in (a wrong password on an already-authed device,
      // etc.) — a fully unauthenticated attempt is silently dropped by
      // AuditLogService's own error-safety, not a bug here.
      AuditLogService.instance.logFailedLogin(email: email.trim());
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<Result<User>> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return const Result.failure('Registration failed. Please try again.');
      }
      await user.updateDisplayName(fullName);

      final profile = UserModel(
        uid: user.uid,
        fullName: fullName,
        email: email.trim(),
        createdAt: DateTime.now(),
      );
      await _firestoreService.set(
        collection: AppConstants.usersCollection,
        docId: user.uid,
        data: profile.toMap(),
      );

      return Result.success(user);
    } catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<Result<User>> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const Result.failure('Google sign-in was cancelled.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        return const Result.failure('Google sign-in failed.');
      }

      // Create a Firestore profile the first time this Google user signs in.
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        final profile = UserModel(
          uid: user.uid,
          fullName: user.displayName ?? '',
          email: user.email ?? '',
          photoUrl: user.photoURL,
          createdAt: DateTime.now(),
        );
        await _firestoreService.set(
          collection: AppConstants.usersCollection,
          docId: user.uid,
          data: profile.toMap(),
        );
      }

      AuditLogService.instance.logLogin(uid: user.uid);
      return Result.success(user);
    } catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<Result<void>> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      // Only attributable if some session happens to be signed in when
      // this is requested (e.g. from an in-app "change email" flow) —
      // the common "forgot password" case is unauthenticated, so this
      // is best-effort per AuditLogService's own error-safety rules.
      final uid = currentUser?.uid;
      if (uid != null) {
        AuditLogService.instance.logPasswordResetRequested(uid: uid, email: email.trim());
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  /// Stage 3.6.2 Part 2 addition — changes the signed-in user's password,
  /// re-authenticating first since Firebase requires a recent sign-in for
  /// this operation. Never logs the password itself, only that a change
  /// happened.
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return const Result.failure('You need to be signed in to change your password.');
    }
    try {
      final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      AuditLogService.instance.logPasswordChanged(uid: user.uid);
      return const Result.success(null);
    } catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<void> signOut() async {
    final uid = currentUser?.uid;
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
    if (uid != null) AuditLogService.instance.logLogout(uid: uid);
  }
}
