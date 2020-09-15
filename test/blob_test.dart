import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:dart_git/git.dart';

void main() {
  test('Reads the blob file correctly', () async {
    var gitRepo = GitRepository(Directory.systemTemp.path);
    var obj = await gitRepo.readObjectFromPath('test/data/blob');

    expect(obj is GitBlob, equals(true));
    expect(obj.serializeData(), equals(ascii.encode('FOO\n')));

    var fileRawBytes = await File('test/data/blob').readAsBytes();
    var fileBytesDefalted = zlib.decode(fileRawBytes);
    expect(obj.serialize(), equals(fileBytesDefalted));
  });
}
