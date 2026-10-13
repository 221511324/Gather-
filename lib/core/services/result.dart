/// A tiny result type so services can report a readable failure without
/// leaking Firebase exception codes into the UI layer.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Ok<T>;
  bool get isFailure => this is Err<T>;

  T? get valueOrNull => this is Ok<T> ? (this as Ok<T>).value : null;
  String? get errorOrNull => this is Err<T> ? (this as Err<T>).message : null;

  R when<R>({required R Function(T value) ok, required R Function(String message) err}) =>
      switch (this) {
        Ok<T>(:final value) => ok(value),
        Err<T>(:final message) => err(message),
      };
}

class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.message);
  final String message;
}
