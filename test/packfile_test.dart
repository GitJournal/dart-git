import 'dart:io';

import 'package:test/test.dart';

import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/idx_file.dart';
import 'package:dart_git/plumbing/pack_file.dart';
import 'lib.dart';

void main() {
  test('Packfile', () async {
    var basePath = 'test/data';
    var packFileName = 'pack-6b2f047eb88137b05be66724152f9924a838e4f9';

    var idxFileBytes = File('$basePath/$packFileName.idx').readAsBytesSync();
    var idxFile = IdxFile.decode(idxFileBytes);

    var packfile =
        await PackFile.fromFile(idxFile, '$basePath/$packFileName.pack');

    var expectedHashes = [
      '350bac933de33894c7691a7225886810da7d7ec9',
      '45d48778e8b6e2537bb75ee389953a651332834d',
      '87a8eae2f1e4c61c193ec66ffca6f152da3826d5',
      'b14df6442ea5a1b382985a6549b85d435376c351',
      'b9b5997cef6cf776b1a990913248764e0e6eb650',
      'e965047ad7c57865823c7d992b1d046ea66edf78',
    ];
    var i = 0;
    var objects = await packfile.getAll();
    for (var obj in objects) {
      expect(obj.hash.toString(), expectedHashes[i]);
      i++;
    }
    expect(i, expectedHashes.length);
  });

  test('Packfile with deltas', () async {
    var basePath = 'test/data';
    var packFileName = 'pack-c1b214c203c64e8021e30390b2d8cf35e8f165c1';

    var idxFileBytes = await File('$basePath/$packFileName.idx').readAsBytes();
    var idxFile = IdxFile.decode(idxFileBytes);

    var packfile =
        await PackFile.fromFile(idxFile, '$basePath/$packFileName.pack');

    var expectedHashes = [
      'eb853bd24cb29c1be6d4210200122e27b19fa7ce',
      'dd72824be0fd14bee06c4bca25e8068f8fb467cc',
      '9105258190f8021c3742a0371d7d740f6322903d',
      'e965047ad7c57865823c7d992b1d046ea66edf78',
      '93c56b0e12c12bb5fb9ca719f7bd0f47b28482e5',
      '028b714854358079cbab43163541b04602cd635a',
      '1d68379bf577e4197f152b2bf81f12d825333bdc',
      'b882c7f54f2b2b2c811eeae1c2e9998d2ce31890',
      'ff541a69fb90597fc0e4ad83904f9f8c4a41533f',
      '30f4be7940c11385ab785b057843a45513ca0eb1',
    ];

    var objects = await packfile.getAll();

    var actualHashes = <String>[];
    for (var obj in objects) {
      actualHashes.add(obj.hash.toString());
    }

    expect(expectedHashes.toSet(), actualHashes.toSet());
  });

  test('Packfile with deltas 2', () async {
    var basePath = 'test/data';
    var packFileName = 'pack-2f0bd00c4566e8a259b86e261ab7ca9910fffbb8';

    var idxFileBytes = await File('$basePath/$packFileName.idx').readAsBytes();
    var idxFile = IdxFile.decode(idxFileBytes);

    var packfile =
        await PackFile.fromFile(idxFile, '$basePath/$packFileName.pack');

    var obj = await packfile
        .object(GitHash('0d2a7502772ce4d1afdec4ed380181acd7ea91f0'));

    expect(obj, isNotNull);
  });

  test('Packfile with Ref Delta', () async {
    var gitDir = await openFixture('test/data/git-ofs-delta.tgz');

    var basePath = '$gitDir/.git/objects/pack';
    var packFileName = 'pack-c544593473465e6315ad4182d04d366c4592b829';

    var idxFileBytes = await File('$basePath/$packFileName.idx').readAsBytes();
    var idxFile = IdxFile.decode(idxFileBytes);

    var packfile =
        await PackFile.fromFile(idxFile, '$basePath/$packFileName.pack');

    var obj = await packfile
        .object(GitHash('6ecf0ef2c2dffb796033e5a02219af86ec6584e5'));

    expect(obj, isNotNull);
  });
}
