import 'dart:convert';
import 'dart:io';

import 'package:file/local.dart';
import 'package:test/test.dart';

import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/storage/object_storage_fs.dart';
import 'package:dart_git/utils/file_mode.dart';

void main() {
  test('Reads the tree file correctly', () async {
    const fs = LocalFileSystem();
    var objStorage = ObjectStorageFS('', fs);

    var fp = 'test/data/tree';
    expect(File(fp).existsSync(), equals(true));

    var data = File(fp).readAsBytesSync();
    var hash = GitHash.compute(GitObject.envelope(
      data: data,
      format: ascii.encode(GitTree.fmt),
    ));

    var obj = objStorage.readObjectFromPath(fp, hash);
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
    expect(
        GitObject.envelope(data: tree.serializeData(), format: tree.format()),
        equals(fileBytesDefalted));
  });

  test('Sorts tree entries using git tree ordering', () {
    var hash = GitHash('e25b29c8946e0e192fae2edc1dabf7be71e8ecf3');
    var tree = GitTree.create([
      GitTreeEntry(mode: GitFileMode.Regular, name: 'a0.md', hash: hash),
      GitTreeEntry(mode: GitFileMode.Dir, name: 'a', hash: hash),
      GitTreeEntry(mode: GitFileMode.Regular, name: 'a.md', hash: hash),
    ]);

    expect(tree.entries.map((entry) => entry.name), ['a.md', 'a', 'a0.md']);
  });
}
