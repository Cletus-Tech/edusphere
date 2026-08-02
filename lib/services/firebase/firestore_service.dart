import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/result.dart';

/// Thin, generic wrapper around Cloud Firestore. Feature modules
/// (Learn, Community, AI Tutor, and future CBT/Marketplace/Scholarships)
/// should go through this service rather than calling
/// FirebaseFirestore.instance directly, so collection access stays
/// consistent and easy to mock in tests.
///
/// Stage 1.3 production hardening: every one-shot read/write goes
/// through [_withRetry], which applies a timeout and a small number of
/// retries with backoff for transient failures (`unavailable`,
/// `deadline-exceeded`, dropped connections). Permission and validation
/// errors are never retried — retrying those just wastes time and hides
/// a real bug. Streams intentionally aren't wrapped here: Firestore's
/// own offline cache already keeps `snapshots()` alive and replays once
/// connectivity returns.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const Duration _timeout = Duration(seconds: 12);
  static const int _maxAttempts = 3;

  Future<Result<T>> _withRetry<T>(String opName, Future<T> Function() op) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final value = await op().timeout(_timeout);
        return Result.success(value);
      } on TimeoutException catch (e) {
        lastError = e;
        AppLogger.warning('$opName timed out (attempt $attempt/$_maxAttempts)', tag: 'firestore');
      } on FirebaseException catch (e) {
        lastError = e;
        if (!_isRetryable(e)) {
          AppLogger.error('$opName failed: ${e.code}', tag: 'firestore', error: e);
          return resultFailureFrom(e);
        }
        AppLogger.warning('$opName failed with ${e.code} (attempt $attempt/$_maxAttempts)',
            tag: 'firestore', error: e);
      } catch (e) {
        lastError = e;
        AppLogger.error('$opName failed', tag: 'firestore', error: e);
        return resultFailureFrom(e);
      }
      if (attempt < _maxAttempts) {
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    return resultFailureFrom(lastError ?? Exception('$opName failed'));
  }

  bool _isRetryable(FirebaseException e) =>
      e.code == 'unavailable' || e.code == 'deadline-exceeded' || e.code == 'aborted';

  Future<Result<void>> set({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    bool merge = true,
  }) {
    return _withRetry('set $collection/$docId', () async {
      await _db.collection(collection).doc(docId).set(data, SetOptions(merge: merge));
    });
  }

  Future<Result<Map<String, dynamic>?>> getDoc({
    required String collection,
    required String docId,
  }) {
    return _withRetry('get $collection/$docId', () async {
      final snapshot = await _db.collection(collection).doc(docId).get();
      return snapshot.data();
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDoc({
    required String collection,
    required String docId,
  }) {
    return _db.collection(collection).doc(docId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection({
    required String collection,
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>>)? query,
    int? limit,
  }) {
    Query<Map<String, dynamic>> ref = _db.collection(collection);
    if (query != null) ref = query(ref);
    if (limit != null) ref = ref.limit(limit);
    return ref.snapshots();
  }

  Future<Result<void>> delete({
    required String collection,
    required String docId,
  }) {
    return _withRetry('delete $collection/$docId', () async {
      await _db.collection(collection).doc(docId).delete();
    });
  }
}
