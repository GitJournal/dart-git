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
  });
}
