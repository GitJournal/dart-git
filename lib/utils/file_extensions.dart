import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:posix/posix.dart' as posix;

extension FSExtensions on File {
  Future<void> chmod(int mode) async {
    posix.chmod(path, mode.toRadixString(8));
  }
}

extension FSExtensions2 on io.File {
  Future<void> chmod(int mode) async {
    posix.chmod(path, mode.toRadixString(8));
  }
}
