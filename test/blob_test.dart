import 'dart:io';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:dart_git/git.dart';

void main() {
  test('Reads the blob file correctly', () async {
    var gitRepo = GitRepository(Directory.systemTemp.path);
    var obj = await gitRepo.readObjectFromPath('test/data/blob');

    expect(obj is GitBlob, equals(true));
    expect(obj.serialize(), equals(ascii.encode('FOO\n')));
  });
}
