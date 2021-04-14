class Result<Success> {
  Success? success;
  Exception? error;

  Result(this.success, {this.error});
  Result.fail(this.error);

  static Future<Result> catchAll(Future<Result> Function() catchFn) async {
    try {
      return catchFn();
    } on Exception catch (e) {
      return Result.fail(e);
    }
  }

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
