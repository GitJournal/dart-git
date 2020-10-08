// This file has been adapted from https://github.com/tarruda/node-git-core/blob/master/src/js/delta.js

bool _isCopyFromSrc(int cmd) => (cmd & 0x80) != 0;
bool _isCopyFromDelta(int cmd) => (cmd & 0x80) == 0 && cmd != 0;

// produces a buffer that is the result of 'delta' applied to 'base'
// algorithm taken from 'patch-delta.c' in the git source tree
List<int> patchDelta(List<int> base, List<int> delta) {
  var copyLength = 0;
  var rvOffset = 0;

  var header = DeltaHeader.decode(delta);
  var offset = header.length;

  // assert the size of the base buffer
  if (header.baseBufferSize != base.length) {
    throw Exception('Invalid base buffer length in header');
  }

  // pre allocate buffer to hold the results
  var rv = List<int>(header.targetBufferSize);

  // start patching
  while (offset < delta.length) {
    var opcode = delta[offset++];
    if (_isCopyFromSrc(opcode)) {
      // copy instruction (copy bytes from base buffer to target buffer)
      var baseOffset = 0;
      copyLength = 0;

      // the state of the next bits will tell us information we need
      // to perform the copy
      // first we get the offset in the source buffer where
      // the copy will start
      if (opcode & 0x01 != 0) baseOffset = delta[offset++];
      if (opcode & 0x02 != 0) baseOffset |= delta[offset++] << 8;
      if (opcode & 0x04 != 0) baseOffset |= delta[offset++] << 16;
      if (opcode & 0x08 != 0) baseOffset |= delta[offset++] << 24;
      // now the amount of bytes to copy
      if (opcode & 0x10 != 0) copyLength = delta[offset++];
      if (opcode & 0x20 != 0) copyLength |= delta[offset++] << 8;
      if (opcode & 0x40 != 0) copyLength |= delta[offset++] << 16;
      if (copyLength == 0) copyLength = 0x10000;

      // copy the data
      var replacement = base.getRange(baseOffset, baseOffset + copyLength);
      _replaceRange(rv, rvOffset, replacement);
    } else if (_isCopyFromDelta(opcode)) {
      // insert instruction (copy bytes from delta buffer to target buffer)
      // amount to copy is specified by the opcode itself
      copyLength = opcode;

      var replacement = delta.getRange(offset, offset + copyLength);
      _replaceRange(rv, rvOffset, replacement);
    } else {
      throw Exception('Invalid delta opcode');
    }

    // advance target position
    rvOffset += copyLength;
  }

  // assert the size of the target buffer
  if (rvOffset != rv.length) {
    throw Exception('Error patching the base buffer');
  }

  return rv;
}

void _replaceRange(List<int> list, int offset, Iterable<int> replaceIter) {
  for (var val in replaceIter) {
    list[offset++] = val;
  }
}

class DeltaHeader {
  int baseBufferSize;
  int targetBufferSize;
  int length;

  // gets sizes of the base buffer/target buffer formatted in LEB128 and
  // the delta header length
  DeltaHeader.decode(List<int> buffer) {
    var offset = 0;

    int nextSize() {
      var byte = buffer[offset++];
      var rv = byte & 0x7f;
      var shift = 7;

      while (byte & 0x80 > 0) {
        byte = buffer[offset++];
        rv |= (byte & 0x7f) << shift;
        shift += 7;
      }

      return rv;
    }

    baseBufferSize = nextSize();
    targetBufferSize = nextSize();
    length = offset;
  }

  @override
  String toString() =>
      'DeltaHeader{baseBufferSize: $baseBufferSize, targetBufferSize: $targetBufferSize, length: $length}';
}
