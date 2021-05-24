class Result<DataType> {
  DataType? data;
  Exception? error;

  Result(this.data, {this.error});
  Result.fail(this.error);

  DataType get() {
    assert(data != null || error != null);

    if (data != null) {
      return data!;
    } else {
      throw error!;
    }
  }

  bool get failed => error != null;
}

Future<Result<T>> catchAll<T>(Future<Result<T>> Function() catchFn) async {
  try {
    return catchFn();
  } on Exception catch (e) {
    return Result.fail(e);
  }
}

Result<Base> downcast<Base, Derived>(Result<Derived> other) {
  return Result(other.data as Base?, error: other.error);
}
