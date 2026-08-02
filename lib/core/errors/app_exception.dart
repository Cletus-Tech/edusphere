import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../utils/result.dart';

/// Every failure category a repository can surface. UI code switches on
/// this instead of parsing message strings, while [message] still gives
/// a ready-to-display, human-friendly string (reusing the Stage 1
/// [friendlyErrorMessage] mapping for auth-specific cases).
enum AppErrorType {
  network,
  authentication,
  permission,
  notFound,
  storage,
  validation,
  unknown,
}

class AppException implements Exception {
  final AppErrorType type;
  final String message;
  final Object? cause;

  const AppException(this.type, this.message, {this.cause});

  factory AppException.from(Object error) {
    if (error is FirebaseAuthException) {
      return AppException(AppErrorType.authentication, friendlyErrorMessage(error), cause: error);
    }
    if (error is FirebaseException) {
      if (error.plugin == 'firebase_storage') {
        return AppException(AppErrorType.storage, 'File upload/download failed. Please try again.', cause: error);
      }
      // Covers Firestore (and any other plugin's) FirebaseException codes.
      switch (error.code) {
        case 'permission-denied':
          return AppException(
            AppErrorType.permission,
            "You don't have permission to do that.",
            cause: error,
          );
        case 'not-found':
          return AppException(AppErrorType.notFound, 'That item could not be found.', cause: error);
        case 'unavailable':
        case 'network-request-failed':
          return AppException(
            AppErrorType.network,
            'No internet connection. Please check your network and try again.',
            cause: error,
          );
        default:
          return AppException(AppErrorType.unknown, 'Something went wrong. Please try again.', cause: error);
      }
    }
    final raw = error.toString();
    if (raw.contains('SocketException') || raw.contains('TimeoutException')) {
      return AppException(
        AppErrorType.network,
        'No internet connection. Please check your network and try again.',
        cause: error,
      );
    }
    return AppException(AppErrorType.unknown, 'Something went wrong. Please try again.', cause: error);
  }

  @override
  String toString() => message;
}

/// Convenience so repositories can go straight from a try/catch to a
/// `Result.failure` using the friendly message, matching the pattern
/// every Stage 1 service already follows.
Result<T> resultFailureFrom<T>(Object error) => Result.failure(AppException.from(error).message);
