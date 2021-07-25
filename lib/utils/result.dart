/// See https://github.com/michaelbull/kotlin-result
class Result<DataType> {
  DataType? data;

  Exception? error;
  StackTrace? stackTrace;

  Result(DataType data) : data = data;
  Result.fail(Exception error, [StackTrace? stackTrace])
      : error = error,
        stackTrace = stackTrace ?? StackTrace.current;
  Result._(this.data, this.error, this.stackTrace);

  DataType getOrThrow() {
    assert(data != null || error != null);

    if (data != null) {
      return data!;
    } else {
      if (stackTrace != null) {
        throw ResultException(error!, stackTrace!);
      }
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

class ResultException implements Exception {
  final Exception exception;
  final StackTrace stackTrace;

  ResultException(this.exception, this.stackTrace);

  @override
  String toString() => exception.toString();
}

Future<Result<T>> catchAll<T>(Future<Result<T>> Function() catchFn) async {
  try {
    return await catchFn();
  } on ResultException catch (e) {
    return Result.fail(e, e.stackTrace);
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
  if (result.stackTrace != null) {
    return Result<A>.fail(result.error!, result.stackTrace);
  } else {
    return Result<A>.fail(result.error!, StackTrace.current);
  }
}

/// Rust style try? operator.
Future<A> tryR<A>(Future<Result<A>> resultFuture) async {
  var result = await resultFuture;
  return result.getOrThrow();
}
