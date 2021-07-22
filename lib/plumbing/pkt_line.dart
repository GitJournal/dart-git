import 'dart:convert';
import 'dart:typed_data';

import 'package:charcode/charcode.dart';
import 'package:meta/meta.dart';

class PktLine {
  static final FlushPkt = Uint8List.fromList([$0, $0, $0, $0]);
  static final FlushPktString = '';
  static const MaxPayloadSize = 65516;
  static const OversizePayloadMax = 65520;
}

class PktLineEncoder {
  var buffer = BytesBuilder();

  void flush() => buffer.add(PktLine.FlushPkt);
  Uint8List toBytes() => buffer.toBytes();

  void add(String str) {
    var bytes = utf8.encode(str);
    buffer.add(bytes);
  }

  void addBytes(List<int> bytes) {
    buffer.add(bytes);
  }

  void addLine(List<int> bytes) {
    if (bytes.length > PktLine.MaxPayloadSize) {
      throw Exception('Payload too long');
    }

    if (bytes.isEmpty) {
      flush();
      return;
    }

    var n = bytes.length + 4;
    var nEncoded = asciiHex16(n);
    addBytes(nEncoded);
    addBytes(bytes);
  }
}

/// Returns the hexadecimal ascii representation of the 16 less
/// significant bits of n.  The length of the returned list will always
/// be 4.  Example: if n is 1234 (0x4d2), the return value will be
/// []byte{'0', '4', 'd', '2'}.
@visibleForTesting
List<int> asciiHex16(int n) {
  var ret = List<int>.filled(4, 0);
  ret[0] = byteToASCIIHex((n & 0xf000) >> 12);
  ret[1] = byteToASCIIHex((n & 0x0f00) >> 8);
  ret[2] = byteToASCIIHex((n & 0x00f0) >> 4);
  ret[3] = byteToASCIIHex(n & 0x000f);

  return ret;
}

/// turns an int8 into its hexadecimal ascii representation.
/// Example: from 11 (0xb) to 'b'.
@visibleForTesting
int byteToASCIIHex(int n) {
  if (n < 10) {
    return $0 + n;
  }

  return $a - 10 + n;
}
