import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:os/file_system.dart' as os_fs;

extension FSExtensions on File {
  void chmodSync(int mode) {
    os_fs.chmodSync(io.File(path), mode);
  }
}

extension FSExtensions2 on io.File {
  void chmodSync(int mode) {
    os_fs.chmodSync(io.File(path), mode);
  }
}
