/// Wraps the outcome of any async operation (auth, Firestore, storage...)
/// so callers are forced to handle both success and failure explicitly.
/// This is the backbone of the "no silent failures" rule: every service
/// method returns a Result instead of throwing or returning null.
sealed class Result<T> {
  const Result();

  const factory Result.success(T data) = Success<T>;
  const factory Result.failure(String message) = Failure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final String message;
  const Failure(this.message);
}

/// Convenience for read-only call sites that just want the value (or
/// null on failure) without a full switch — e.g. a best-effort preview
/// where showing "not found" and "failed to load" the same way is fine.
extension ResultDataOrNull<T> on Result<T> {
  T? get dataOrNull => switch (this) {
        Success(data: final d) => d,
        Failure() => null,
      };
}

/// Converts common Firebase/network exceptions into messages a user can
/// actually read, instead of surfacing raw exception strings.
String friendlyErrorMessage(Object error) {
  final raw = error.toString();
  if (raw.contains('network-request-failed') || raw.contains('SocketException')) {
    return 'No internet connection. Please check your network and try again.';
  }
  if (raw.contains('user-not-found')) {
    return 'No account found with that email.';
  }
  if (raw.contains('wrong-password') || raw.contains('invalid-credential')) {
    return 'Incorrect email or password.';
  }
  if (raw.contains('email-already-in-use')) {
    return 'An account with this email already exists.';
  }
  if (raw.contains('weak-password')) {
    return 'Please choose a stronger password.';
  }
  if (raw.contains('too-many-requests')) {
    return 'Too many attempts. Please try again in a few minutes.';
  }
  return 'Something went wrong. Please try again.';
}
