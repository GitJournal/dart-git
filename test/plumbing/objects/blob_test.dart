import 'dart:convert';
import 'dart:io';

import 'package:file/local.dart';
import 'package:test/test.dart';

import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/storage/object_storage_fs.dart';

void main() {
  test('Reads the blob file correctly', () async {
    const fs = LocalFileSystem();
    var objStorage = ObjectStorageFS('', fs);

    var fp = 'test/data/blob';
    var data = File(fp).readAsBytesSync();
    var hash = GitHash.compute(GitObject.envelope(
      data: data,
      format: ascii.encode(GitBlob.fmt),
    ));

    var obj = objStorage.readObjectFromPath(fp, hash).getOrThrow();

    expect(obj is GitBlob, equals(true));
    expect(obj.serializeData(), equals(ascii.encode('FOO\n')));

    var fileRawBytes = await File('test/data/blob').readAsBytes();
    var fileBytesDefalted = zlib.decode(fileRawBytes);
    expect(
      GitObject.envelope(data: obj.serializeData(), format: obj.format()),
      equals(fileBytesDefalted),
    );
  });
}
