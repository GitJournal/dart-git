import 'dart:io';

import 'package:dart_git/plumbing/idx_file.dart';
import 'package:dart_git/plumbing/pack_file.dart';
import 'package:test/test.dart';

void main() {
  test('Packfile', () async {
    var basePath = 'test/data';
    var packFileName = 'pack-6b2f047eb88137b05be66724152f9924a838e4f9';

    var idxFileBytes = File('$basePath/$packFileName.idx').readAsBytesSync();
    var idxFile = IdxFile.decode(idxFileBytes);

    var packfile = PackFile.decode(idxFile, '$basePath/$packFileName.pack');

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
      expect(obj.hash().toString(), expectedHashes[i]);
      i++;
    }
    expect(i, expectedHashes.length);
  });
}
