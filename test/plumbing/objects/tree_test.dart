import 'dart:io';

import 'package:file/local.dart';
import 'package:test/test.dart';

import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/storage/object_storage.dart';

void main() {
  test('Reads the tree file correctly', () async {
    const fs = LocalFileSystem();
    var objStorage = ObjectStorage('', fs);

    var obj = (await objStorage.readObjectFromPath('test/data/tree')).get();
    expect(obj is GitTree, equals(true));

    var tree = obj as GitTree;
    expect(tree.entries.length, 2);

    var leaf0 = tree.entries[0];
    expect(leaf0.mode.toString(), '100644');
    expect(leaf0.hash.toString(), '43fcaffe80f693d06f3c309e354bdbff5d6baa43');
    expect(leaf0.name, 'c.md');

    var leaf1 = tree.entries[1];
    expect(leaf1.mode.toString(), '100644');
    expect(leaf1.hash.toString(), '61f69766977e3d234e15bd1a58c01aa697039439');
    expect(leaf1.name, 'd.md');

    var fileRawBytes = await fs.file('test/data/tree').readAsBytes();
    var fileBytesDefalted = zlib.decode(fileRawBytes);
    expect(tree.serialize(), equals(fileBytesDefalted));
  });
}
