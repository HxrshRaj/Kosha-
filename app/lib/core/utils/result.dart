import '../network/api_exception.dart';

/// Explicit success/failure wrapper returned by every service call, so
/// callers must handle the error path instead of it being swallowed by a
/// try/catch that only logs.
sealed class Result<T> {
  const Result();

  factory Result.ok(T value) = Ok<T>;
  factory Result.err(ApiException error) = Err<T>;

  R when<R>({
    required R Function(T value) ok,
    required R Function(ApiException error) err,
  }) {
    final self = this;
    if (self is Ok<T>) return ok(self.value);
    if (self is Err<T>) return err(self.error);
    throw StateError('Unreachable');
  }
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

class Err<T> extends Result<T> {
  final ApiException error;
  const Err(this.error);
}
