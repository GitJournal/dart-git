import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/objects/blob.dart';

void main() {
  test('Reads the blob file correctly', () async {
    var repoPath = Directory.systemTemp.path;

    await GitRepository.init(repoPath);
    var gitRepo = await GitRepository.load(repoPath);

    var obj = await gitRepo.readObjectFromPath('test/data/blob');

    expect(obj is GitBlob, equals(true));
    expect(obj.serializeData(), equals(ascii.encode('FOO\n')));

    var fileRawBytes = await File('test/data/blob').readAsBytes();
    var fileBytesDefalted = zlib.decode(fileRawBytes);
    expect(obj.serialize(), equals(fileBytesDefalted));
  });
}
