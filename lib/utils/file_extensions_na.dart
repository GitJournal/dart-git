import 'dart:io' as io;

import 'package:file/file.dart';

extension FSExtensions on File {
  void chmodSync(int mode) {
    throw UnimplementedError();
  }
}

extension FSExtensions2 on io.File {
  void chmodSync(int mode) {
    throw UnimplementedError();
  }
}
