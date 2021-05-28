import 'package:buffer/buffer.dart';
import 'package:file/file.dart';

final _maskContinue = 128; // 1000 000
final _maskLength = 127; // 0111 1111
final _lengthBits = 7; // subsequent bytes has 7 bits to store the length

extension BytesDataReader on ByteDataReader {
  // readVariableWidthInt reads and returns an int in Git VLQ special format:
  //
  // Ordinary VLQ has some redundancies, example:  the number 358 can be
  // encoded as the 2-octet VLQ 0x8166 or the 3-octet VLQ 0x808166 or the
  // 4-octet VLQ 0x80808166 and so forth.
  //
  // To avoid these redundancies, the VLQ format used in Git removes this
  // prepending redundancy and extends the representable range of shorter
  // VLQs by adding an offset to VLQs of 2 or more octets in such a way
  // that the lowest possible value for such an (N+1)-octet VLQ becomes
  // exactly one more than the maximum possible value for an N-octet VLQ.
  // In particular, since a 1-octet VLQ can store a maximum value of 127,
  // the minimum 2-octet VLQ (0x8000) is assigned the value 128 instead of
  // 0. Conversely, the maximum value of such a 2-octet VLQ (0xff7f) is
  // 16511 instead of just 16383. Similarly, the minimum 3-octet VLQ
  // (0x808000) has a value of 16512 instead of zero, which means
  // that the maximum 3-octet VLQ (0xffff7f) is 2113663 instead of
  // just 2097151.  And so forth.
  //
  // This is how the offset is saved in C:
  //
  //     dheader[pos] = ofs & 127;
  //     while (ofs >>= 7)
  //         dheader[--pos] = 128 | (--ofs & 127);
  //
  int readVariableWidthInt() {
    var c = readInt8();

    var v = c & _maskLength;
    while (c & _maskContinue > 0) {
      v++;

      c = readInt8();

      v = (v << _lengthBits) + (c & _maskLength);
    }

    return v;
  }

  List<int> readUntil(int r) {
    var l = <int>[];
    while (true) {
      var c = readInt8();
      if (c == r) {
        return l;
      }
      l.add(c);
    }
  }
}

extension RandomFileReader on RandomAccessFile {
  Future<int> readVariableWidthInt() async {
    var c = await readByte();

    var v = c & _maskLength;
    while (c & _maskContinue > 0) {
      v++;

      c = await readByte();

      v = (v << _lengthBits) + (c & _maskLength);
    }

    return v;
  }
}
