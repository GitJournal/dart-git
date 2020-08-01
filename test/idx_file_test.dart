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
}
