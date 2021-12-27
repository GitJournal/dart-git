import 'dart:convert';
import 'dart:io';

import 'package:file/local.dart';
import 'package:test/test.dart';

import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/storage/object_storage_fs.dart';

void main() {
  test('Reads the blob file correctly', () async {
    const fs = LocalFileSystem();
    var objStorage = ObjectStorageFS('', fs);

    var obj = objStorage.readObjectFromPath('test/data/blob').getOrThrow();

    expect(obj is GitBlob, equals(true));
    expect(obj.serializeData(), equals(ascii.encode('FOO\n')));

    var fileRawBytes = await File('test/data/blob').readAsBytes();
    var fileBytesDefalted = zlib.decode(fileRawBytes);
    expect(obj.serialize(), equals(fileBytesDefalted));
  });
}
