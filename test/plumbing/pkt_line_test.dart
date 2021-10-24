import 'dart:convert';

import 'package:test/test.dart';

import 'package:dart_git/plumbing/pkt_line.dart';

void main() {
  group('Encoder', () {
    test('byteToASCIIHex', () {
      expect(byteToASCIIHex(5), 53);
      expect(byteToASCIIHex(15), 102);
      expect(byteToASCIIHex(ascii.encode('a').first), 184);
      expect(byteToASCIIHex(ascii.encode('1').first), 136);
    });

    test('asciiHex16', () {
      expect(asciiHex16(10), [48, 48, 48, 97]);
    });

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
        // ['hello\n', PktLine.FlushPktString, '000ahello\n\0\0\0\0'],
        ['hello\n', 'world!\n', 'foo', '000ahello\n000bworld!\n0007foo'],
        [
          'hello\n',
          PktLine.FlushPktString,
          'world!\n',
          'foo',
          PktLine.FlushPktString,
          // '000ahello\n\0\0\0\0000bworld!\n0007foo\0\0\0\0'
        ],
        [
          'a' * PktLine.MaxPayloadSize,
          'fff0' + 'a' * PktLine.MaxPayloadSize,
        ],
        // [
        //   'b' * PktLine.MaxPayloadSize,
        //   'b' * PktLine.MaxPayloadSize,
        //   // Expected
        //   'fff0' +
        //       ('a' * PktLine.MaxPayloadSize) +
        //       'fff0' +
        //       ('b' * PktLine.MaxPayloadSize),
        // ],
      ];
      for (var data in testData) {
        var input = data.sublist(0, data.length - 1);
        var output = data.last;

        var encoder = PktLineEncoder();
        for (var i in input) {
          encoder.addLine(utf8.encode(i));
        }

        var actual = encoder.toBytes();
        expect(actual, utf8.encode(output));
      }
    });

    // TODO: Error too long
    var _ = [
      ['a' * (PktLine.MaxPayloadSize + 1)],
      ['hello world!', 'a' * (PktLine.MaxPayloadSize + 1)],
      ['hello world!', 'a' * (PktLine.MaxPayloadSize + 1), 'foo'],
    ];
  });
}
