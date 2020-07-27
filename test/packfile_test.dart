import 'dart:io';

import 'package:dart_git/plumbing/pack_file.dart';
import 'package:test/test.dart';

void main() {
  test('Packfile', () async {
    var filePath =
        'test/data/pack-6b2f047eb88137b05be66724152f9924a838e4f9.pack';
    var packfile = PackFile.decode(File(filePath).readAsBytesSync());

    var expectedHashes = [
      '87a8eae2f1e4c61c193ec66ffca6f152da3826d5',
      '350bac933de33894c7691a7225886810da7d7ec9',
      '45d48778e8b6e2537bb75ee389953a651332834d',
      'e965047ad7c57865823c7d992b1d046ea66edf78',
      'b14df6442ea5a1b382985a6549b85d435376c351',
      'b9b5997cef6cf776b1a990913248764e0e6eb650',
    ];
    var i = 0;
    for (var obj in packfile.getAll()) {
      expect(obj.hash(), expectedHashes[i]);
      i++;
    }
    expect(i, expectedHashes.length);
  });
}
