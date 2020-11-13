import 'dart:io';

import 'package:test/test.dart';

import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/index.dart';

void main() {
  test('Decode', () async {
    var bytes =
        File('test/data/indexes/index-7a725350b88b05ca03541b59dd0649fda7f521f2')
            .readAsBytesSync();
    var index = GitIndex.decode(bytes);

    expect(index.versionNo, 2);
    expect(index.entries.length, 9);
  });

  test('Decode Entries', () async {
    var bytes =
        File('test/data/indexes/index-7a725350b88b05ca03541b59dd0649fda7f521f2')
            .readAsBytesSync();
    var index = GitIndex.decode(bytes);

    var e = index.entries[0];

    expect(e.cTime.millisecondsSinceEpoch ~/ 1000, 1480626693);
    expect(e.cTime.millisecond * 1000 + e.cTime.microsecond, 498593596 ~/ 1000);
    expect(e.mTime.millisecondsSinceEpoch ~/ 1000, 1480626693);
    expect(e.mTime.millisecond * 1000 + e.mTime.microsecond, 498593596 ~/ 1000);

    expect(e.dev, 39);
    expect(e.ino, 140626);
    expect(e.mode, GitFileMode.Regular);
    expect(e.uid, 1000);
    expect(e.gid, 100);
    expect(e.fileSize, 189);
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

    var bytes =
        File('test/data/indexes/index-7a725350b88b05ca03541b59dd0649fda7f521f2')
            .readAsBytesSync();
    var index = GitIndex.decode(bytes);
    expect(index.cache, expectedEntries);
  });

  test('Serialize', () async {
    var index = GitIndex(versionNo: 2);
    var entry = GitIndexEntry(
      cTime: DateTime.now(),
      mTime: DateTime.now(),
      dev: 4242,
      ino: 424242,
      mode: GitFileMode.Regular,
      uid: 84,
      gid: 8484,
      fileSize: 42,
      stage: GitFileStage.TheirMode,
      hash: GitHash('e25b29c8946e0e192fae2edc1dabf7be71e8ecf3'),
      path: 'foo',
    );
    index.entries.add(entry);

    var bytes = index.serialize();
    var rIndex = GitIndex.decode(bytes);

    expect(rIndex.versionNo, index.versionNo);
    expect(rIndex.entries, index.entries);
  });

  test('Decode Merge Conflict', () {
    // Test adapted from go-git/plumbing/format/index/decoder_test
    var bytes =
        File('test/data/indexes/index-4870d54b5b04e43da8cf99ceec179d9675494af8')
            .readAsBytesSync();

    var index = GitIndex.decode(bytes);

    expect(index.versionNo, 2);
    expect(index.entries.length, 13);

    for (var i = 4; i < 7; i++) {
      var e = index.entries[i];

      expect(e.cTime.millisecondsSinceEpoch, 0);
      expect(e.mTime.millisecondsSinceEpoch, 0);
      expect(e.dev, 0);
      expect(e.ino, 0);
      expect(e.uid, 0);
      expect(e.gid, 0);
      expect(e.fileSize, 0);
      expect(e.path, 'go/example.go');
    }

    expect(index.entries[4].stage, GitFileStage.AncestorMode);
    expect(index.entries[5].stage, GitFileStage.OurMode);
    expect(index.entries[6].stage, GitFileStage.TheirMode);

    expect(index.entries[4].hash,
        GitHash('880cd14280f4b9b6ed3986d6671f907d7cc2a198'));
    expect(index.entries[5].hash,
        GitHash('d499a1a0b79b7d87a35155afd0c1cce78b37a91c'));
    expect(index.entries[6].hash,
        GitHash('14f8e368114f561c38e134f6e68ea6fea12d77ed'));
  });

  test('End of index entry', () {
    // Test adapted from go-git/plumbing/format/index/decoder_test
    var bytes =
        File('test/data/indexes/index-ab06771a67110b976953d34400d4dbc465ccd2d9')
            .readAsBytesSync();

    var index = GitIndex.decode(bytes);

    expect(index.versionNo, 2);
    expect(index.endOfIndexEntry.offset, 716);
    expect(index.endOfIndexEntry.hash,
        GitHash('922e89d9ffd7cefce93a211615b2053c0f42bd78'));
  }, skip: true);

  test('Decode go-git-fixtures indexes', () async {
    var dir = Directory('test/data/indexes');
    await for (var file in dir.list()) {
      print('File: ${file.path}');
      var bytes = await File(file.path).readAsBytes();
      var index = GitIndex.decode(bytes);

      expect(index.versionNo, 2);
    }
  }, skip: true);
}
