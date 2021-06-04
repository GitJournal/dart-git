import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';

class PktLine {
  static final FlushPkt = Uint8List.fromList([0, 0, 0, 0]);
  static final FlushPktString = ascii.decode(FlushPkt);
  static const MaxPayloadSize = 65516;
  static const OversizePayloadMax = 65520;
}

class PktLineEncoder {
  var buffer = BytesBuilder(copy: false);

  void flush() => buffer.add(PktLine.FlushPkt);
  Uint8List toBytes() => buffer.toBytes();

  void add(String str) {
    var bytes = utf8.encode(str);
    buffer.add(bytes);
  }

  void addBytes(List<int> bytes) {
    buffer.add(bytes);
  }
}

void main() {
  group('Encoder', () {
    test('Flush', () {
      var encoder = PktLineEncoder();
      encoder.flush();
      var bytes = encoder.toBytes();
      expect(bytes, PktLine.FlushPkt);
    });

    // TODO: Test encoding all of these
    test('Encoding', () {
      var testData = [
        ['hello\n', '000ahello\n'],
        ['hello\n', '0000' /*flush*/, '000ahello\n0000'],
        ['hello\n', 'world\n', 'foo', '000ahello\n000bworld!\n0007foo'],
        [
          'hello\n',
          '0000',
          'world\n',
          'foo',
          '0000',
          '000ahello\n0000000bworld!\n0007foo0000'
        ],
        [
          'a' * PktLine.MaxPayloadSize,
          'fff0' + 'a' * PktLine.MaxPayloadSize,
        ],
        [
          'b' * PktLine.MaxPayloadSize,
          'b' * PktLine.MaxPayloadSize,
          // Expected
          'fff0' + 'a' * PktLine.MaxPayloadSize,
          'fff0' + 'b' * PktLine.MaxPayloadSize,
        ],
      ];
      for (var data in testData) {
        var input = data.sublist(0, data.length - 2);
        var output = data.last;

        var encoder = PktLineEncoder();
        for (var i in input) {
          encoder.add(i);
        }

        expect(encoder.toBytes(), output);
      }
    }, skip: true);

    // TODO: Error too long
    var _ = [
      ['a' * (PktLine.MaxPayloadSize + 1)],
      ['hello world!', 'a' * (PktLine.MaxPayloadSize + 1)],
      ['hello world!', 'a' * (PktLine.MaxPayloadSize + 1), 'foo'],
    ];
  });
}
