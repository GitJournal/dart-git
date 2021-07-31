import 'dart:io' as io;

import 'package:file/file.dart';

extension FSExtensions on File {
  Future<void> chmod(int mode) async {
    throw UnimplementedError();
  }
}

extension FSExtensions2 on io.File {
  Future<void> chmod(int mode) async {
    throw UnimplementedError();
  }
}
