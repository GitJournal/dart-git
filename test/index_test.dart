import 'dart:io';

import 'package:test/test.dart';
import 'package:dart_git/plumbing/index.dart';

void main() {
  test('Decode', () async {
    var bytes = File('test/data/index').readAsBytesSync();
    var index = GitIndex.decode(bytes);

    expect(index.versionNo, 2);
    expect(index.entries.length, 9);
  });
}
