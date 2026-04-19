sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;
}

class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;
}

class FailureResult<T> extends Result<T> {
  const FailureResult(this.message);

  final String message;
}
