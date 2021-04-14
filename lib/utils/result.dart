class Result<Success> {
  Success? success;
  Exception? error;

  Result(this.success, {this.error});
  Result.fail(this.error);

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
