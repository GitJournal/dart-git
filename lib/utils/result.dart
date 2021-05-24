class Result<Success> {
  Success? success;
  Exception? error;

  Result(this.success, {this.error});
  Result.fail(this.error);

  Success get() {
    assert(success != null || error != null);

    if (success != null) {
      return success!;
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
  return Result(other.success as Base?, error: other.error);
}
