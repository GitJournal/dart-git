/// See https://github.com/michaelbull/kotlin-result
class Result<DataType> {
  DataType? data;

  Exception? error;
  StackTrace? stackTrace;

  Result(DataType data) : data = data;
  Result.fail(Exception error, [this.stackTrace]) : error = error;
  Result._(this.data, this.error, this.stackTrace);

  DataType getOrThrow() {
    assert(data != null || error != null);

    if (data != null) {
      return data!;
    } else {
      throw error!;
    }
  }

  void throwOnError() {
    if (isFailure) {
      throw error!;
    }
  }

  bool get isFailure => error != null;
  bool get isSuccess => error == null;
}

Future<Result<T>> catchAll<T>(Future<Result<T>> Function() catchFn) async {
  try {
    return catchFn();
  } on Exception catch (e, stackTrace) {
    return Result.fail(e, stackTrace);
  }
}

Result<Base> downcast<Base, Derived>(Result<Derived> other) {
  return Result._(other.data as Base, other.error, other.stackTrace);
}

extension ResultFuture<T> on Future<Result<T>> {
  /// Convenience method to have to avoid putting parenthesis around the
  /// await expression
  Future<T> getOrThrow() async {
    var result = await this;
    return result.getOrThrow();
  }

  Future<void> throwOnError() async {
    var result = await this;
    result.throwOnError();
  }
}

Result<A> fail<A, B>(Result<B> result) {
  assert(result.error != null);
  return Result<A>.fail(result.error!);
}

/// Rust style try? operator.
Future<A> tryR<A>(Future<Result<A>> resultFuture) async {
  var result = await resultFuture;
  return result.getOrThrow();
}
