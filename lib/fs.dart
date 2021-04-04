// @dart=2.9

import 'package:file/file.dart';
import 'package:file/local.dart';

class LocalFileSystemWithChecks extends LocalFileSystem {
  const LocalFileSystemWithChecks();

  @override
  Directory directory(dynamic path) {
    assert(path is String);
    assert((path as String).startsWith('/'));
    return super.directory(path);
  }

  @override
  File file(dynamic path) {
    assert(path is String);
    assert((path as String).startsWith('/'));
    return super.file(path);
  }

  @override
  Link link(dynamic path) {
    assert(path is String);
    assert((path as String).startsWith('/'));
    return super.link(path);
  }
}
