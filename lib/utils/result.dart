class Result<Success> {
  Success? success;
  Exception? error;

  Result._({this.success, this.error});
  Result.success(Success s) : this._(success: s);
  Result.failure(Exception f) : this._(error: f);

  Result(Success Function() catchFn) {
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
