import 'dart:io';

import 'package:dart_git/git_hash.dart';
import 'package:test/test.dart';
import 'package:dart_git/plumbing/index.dart';

void main() {
  test('Decode', () async {
    var bytes = File('test/data/index').readAsBytesSync();
    var index = GitIndex.decode(bytes);

    expect(index.versionNo, 2);
    expect(index.entries.length, 9);
  });

  test('Decode Entries', () async {
    var bytes = File('test/data/index').readAsBytesSync();
    var index = GitIndex.decode(bytes);

    var e = index.entries[0];

    expect(e.ctimeSeconds, 1480626693);
    expect(e.ctimeNanoSeconds, 498593596);
    expect(e.mtimeSeconds, 1480626693);
    expect(e.mtimeNanoSeconds, 498593596);
    expect(e.dev, 39);
    expect(e.ino, 140626);
    // FIXME: Check the mode!
    expect(e.uid, 1000);
    expect(e.gid, 100);
    expect(e.size, 189);
    expect(e.hash.toString(), '32858aad3c383ed1ff0a0f9bdf231d54a00c9e88');
    expect(e.path, '.gitignore');

    e = index.entries[1];
    expect(e.path, 'CHANGELOG');

    expect(index.entries.length, 9);
  });

  test('Decode Cache Tree Extension', () async {
    var expectedEntries = <TreeEntry>[
      TreeEntry(
          path: '',
          numEntries: 9,
          numSubTrees: 4,
          hash: GitHash('a8d315b2b1c615d43042c3a62402b8a54288cf5c')),
      TreeEntry(
          path: 'go',
          numEntries: 1,
          numSubTrees: 0,
          hash: GitHash('a39771a7651f97faf5c72e08224d857fc35133db')),
      TreeEntry(
          path: 'php',
          numEntries: 1,
          numSubTrees: 0,
          hash: GitHash('586af567d0bb5e771e49bdd9434f5e0fb76d25fa')),
      TreeEntry(
          path: 'json',
          numEntries: 2,
          numSubTrees: 0,
          hash: GitHash('5a877e6a906a2743ad6e45d99c1793642aaf8eda')),
      TreeEntry(
          path: 'vendor',
          numEntries: 1,
          numSubTrees: 0,
          hash: GitHash('cf4aa3b38974fb7d81f367c0830f7d78d65ab86b')),
    ];

    var bytes = File('test/data/index').readAsBytesSync();
    var index = GitIndex.decode(bytes);
    expect(index.cache, expectedEntries);
  });

  test('Serialize', () async {
    var bytes = File('test/data/index').readAsBytesSync();
    var index = GitIndex.decode(bytes);

    expect(index.serialize(), bytes);
  });
}
