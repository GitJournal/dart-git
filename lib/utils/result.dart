class Result<DataType> {
  DataType? data;
  Exception? error;

  Result(DataType data, {this.error}) : data = data;
  Result.fail(Exception error) : error = error;

  DataType get() {
    assert(data != null || error != null);

    if (data != null) {
      return data!;
    } else {
      throw error!;
    }
  }

  bool get failed => error != null;
  bool get succeeded => error == null;
}

Future<Result<T>> catchAll<T>(Future<Result<T>> Function() catchFn) async {
  try {
    return catchFn();
  } on Exception catch (e) {
    return Result.fail(e);
  }
}

Result<Base> downcast<Base, Derived>(Result<Derived> other) {
  return Result(other.data as Base, error: other.error);
}

extension ResultFuture<T> on Future<Result<T>> {
  /// Convenience method to have to avoid putting parenthesis around the
  /// await expression
  Future<T> get() async {
    var result = await this;
    return result.get();
  }
}

Result<A> fail<A, B>(Result<B> result) {
  assert(result.error != null);
  return Result<A>.fail(result.error!);
}

/// Rust style try? operator.
Future<A> tryR<A>(Future<Result<A>> resultFuture) async {
  var result = await resultFuture;
  return result.get();
}
