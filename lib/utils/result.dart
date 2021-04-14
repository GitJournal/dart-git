class Result<Success> {
  Success? success;
  Exception? error;

  Result._({this.success, this.error});
  Result(Success s) : this._(success: s);
  Result.fail(Exception f) : this._(error: f);

  Result.catchAll(Success Function() catchFn) {
    try {
      success = catchFn();
    } on Exception catch (e) {
      error = e;
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
