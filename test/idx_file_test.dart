import 'dart:io';

import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/idx_file.dart';
import 'package:test/test.dart';

void main() {
  test('IdxFile Parser', () async {
    var filePath =
        'test/data/pack-6b2f047eb88137b05be66724152f9924a838e4f9.idx';
    var idxFile = IdxFile.decode(File(filePath).readAsBytesSync());

    var expectedData = [
      IdxFileEntry(
        hash: GitHash('350bac933de33894c7691a7225886810da7d7ec9'),
        offset: 161,
        crc32: 1778424872,
      ),
      IdxFileEntry(
        hash: GitHash('45d48778e8b6e2537bb75ee389953a651332834d'),
        offset: 308,
        crc32: 2645610235,
      ),
      IdxFileEntry(
        hash: GitHash('87a8eae2f1e4c61c193ec66ffca6f152da3826d5'),
        offset: 12,
        crc32: 425342914,
      ),
      IdxFileEntry(
        hash: GitHash('b14df6442ea5a1b382985a6549b85d435376c351'),
        offset: 296,
        crc32: 2171668943,
      ),
      IdxFileEntry(
        hash: GitHash('b9b5997cef6cf776b1a990913248764e0e6eb650'),
        offset: 377,
        crc32: 1161077890,
      ),
      IdxFileEntry(
        hash: GitHash('e965047ad7c57865823c7d992b1d046ea66edf78'),
        offset: 281,
        crc32: 39477847,
      ),
    ];

    expect(idxFile.entries, expectedData);
  });

  test('IdxFile Parser 64bit', () async {
    var expectedData = [
      IdxFileEntry(
        hash: GitHash('03fc8d58d44267274edef4585eaeeb445879d33f'),
        offset: 1601322837,
        crc32: 2459826858,
      ),
      IdxFileEntry(
        hash: GitHash('1b8995f51987d8a449ca5ea4356595102dc2fbd4'),
        offset: 5894072943,
        crc32: 562544726,
      ),
      IdxFileEntry(
        hash: GitHash('303953e5aa461c203a324821bc1717f9b4fff895'),
        offset: 12,
        crc32: 3157556300,
      ),
      IdxFileEntry(
        hash: GitHash('35858be9c6f5914cbe6768489c41eb6809a2bceb'),
        offset: 5924278919,
        crc32: 2626279890,
      ),
      IdxFileEntry(
        hash: GitHash('5296768e3d9f661387ccbff18c4dea6c997fd78c'),
        offset: 142,
        crc32: 3452053570,
      ),
      IdxFileEntry(
        hash: GitHash('8f3ceb4ea4cb9e4a0f751795eb41c9a4f07be772'),
        offset: 2646996529,
        crc32: 2786979722,
      ),
      IdxFileEntry(
        hash: GitHash('90eba326cdc4d1d61c5ad25224ccbf08731dd041'),
        offset: 3707047470,
        crc32: 1905521594,
      ),
      IdxFileEntry(
        hash: GitHash('bab53055add7bc35882758a922c54a874d6b1272'),
        offset: 5323223332,
        crc32: 2888211342,
      ),
      IdxFileEntry(
        hash: GitHash('e0d1d625010087f79c9e01ad9d8f95e1628dda02'),
        offset: 3452385606,
        crc32: 113156480,
      ),
    ];

    var filePath = 'test/data/pack-64bit.idx';
    var idxFile = IdxFile.decode(File(filePath).readAsBytesSync());
    expect(idxFile.entries, expectedData);
  });
}
