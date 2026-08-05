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
        return Result.failure(
          'Account created, but setting up your profile failed: $message',
        );
      }

      return Result.success(user);
    } catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

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
      final uid = currentUser?.uid;
      if (uid != null) {
        AuditLogService.instance.logPasswordResetRequested(uid: uid, email: email.trim());
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

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
