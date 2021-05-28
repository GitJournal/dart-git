// This file has been adapted from https://github.com/tarruda/node-git-core/blob/master/src/js/delta.js

import 'dart:typed_data';

bool _isCopyFromSrc(int cmd) => (cmd & 0x80) != 0;
bool _isCopyFromDelta(int cmd) => (cmd & 0x80) == 0 && cmd != 0;

// FIXME: Write tests

// produces a buffer that is the result of 'delta' applied to 'base'
// algorithm taken from 'patch-delta.c' in the git source tree
Uint8List patchDelta(Uint8List base, Uint8List delta) {
  var copyLength = 0;
  var rvOffset = 0;

  var header = DeltaHeader.decode(delta);
  var offset = header.offset;

  // assert the size of the base buffer
  if (header.baseBufferSize != base.length) {
    throw Exception('Invalid base buffer length in header');
  }

  // pre allocate buffer to hold the results
  var rv = Uint8List(header.targetBufferSize);

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

      assert(offset + copyLength <= delta.length);
      assert(rvOffset + copyLength <= rv.length);

      var replacement = delta.getRange(offset, offset + copyLength);
      _replaceRange(rv, rvOffset, replacement);
      offset += copyLength;
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

void _replaceRange(Uint8List list, int offset, Iterable<int> replaceIter) {
  for (var val in replaceIter) {
    list[offset++] = val;
  }
}

class DeltaHeader {
  late int baseBufferSize;
  late int targetBufferSize;
  int offset = 0;

  DeltaHeader(this.baseBufferSize, this.targetBufferSize);

  // gets sizes of the base buffer/target buffer formatted in LEB128 and
  // the delta header length
  // FIXME: What if the buffer is too small?
  DeltaHeader.decode(Uint8List buffer) {
    offset = 0;

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
  }

  Uint8List encode() {
    var opcodes = Uint8List(0);

    void _encode(int size) {
      opcodes.add(size & 0x7f);
      size = _zeroFillRightShift(size, 7);

      while (size > 0) {
        opcodes[opcodes.length - 1] |= 0x80;
        opcodes.add(size & 0x7f);
        size = size >> 7;
      }
    }

    _encode(baseBufferSize);
    _encode(targetBufferSize);

    return opcodes;
  }

  @override
  String toString() =>
      'DeltaHeader{baseBufferSize: $baseBufferSize, targetBufferSize: $targetBufferSize, offset: $offset}';
}

// FIXME: When >>> is implemented use it - https://github.com/dart-lang/language/issues/120
int _zeroFillRightShift(int n, int amount) {
  return (n & 0xffffffffffffffff) >> amount;
}

// the insert instruction is just the number of bytes to copy from
// delta buffer(following the opcode) to target buffer.
// it must be less than 128 since when the MSB is set it will be a
// copy opcode
Uint8List emitInsert(Uint8List opcodes, Uint8List buffer, int length) {
  if (length > 127) {
    // TODO: Implement from the go code
    throw Exception('invalid insert opcode');
  }

  opcodes.add(length);

  for (var i = 0; i < length; i++) {
    opcodes.add(buffer[i]);
  }

  return opcodes;
}

List<int?> emitCopy(List<int?> opcodes, Uint8List source, int offset, int len) {
  int code, codeIdx;

  opcodes.add(null);
  codeIdx = opcodes.length - 1;
  code = 0x80; // set the MSB

  // offset and length are written using a compact encoding
  // where the state of 7 lower bits specify the meaning of
  // the bytes that follow
  if (offset & 0xff > 0) {
    opcodes.add(offset & 0xff);
    code |= 0x01;
  }

  if (offset & 0xff00 > 0) {
    opcodes.add(_zeroFillRightShift(offset & 0xff00, 8));
    code |= 0x02;
  }

  if (offset & 0xff0000 > 0) {
    opcodes.add(_zeroFillRightShift(offset & 0xff0000, 16));
    code |= 0x04;
  }

  if (offset & 0xff000000 > 0) {
    opcodes.add(_zeroFillRightShift(offset & 0xff000000, 24));
    code |= 0x08;
  }

  if (len & 0xff > 0) {
    opcodes.add(len & 0xff);
    code |= 0x10;
  }

  if (len & 0xff00 > 0) {
    opcodes.add(_zeroFillRightShift(len & 0xff00, 8));
    code |= 0x20;
  }

  if (len & 0xff0000 > 0) {
    opcodes.add(_zeroFillRightShift(len & 0xff0000, 16));
    code |= 0x40;
  }

  // place the code at its position
  opcodes[codeIdx] = code;

  return opcodes;
}

// produces a buffer that contains instructions on how to
// construct 'target' from 'source' using git copy/insert encoding.
// adapted from the algorithm described in the paper
// 'File System Support for Delta Compression'.
//
// key differences are:
//  - The block size is variable and determined by linefeeds or
//    chunk of 90 bytes whatever comes first
//  - instead of using fingerprints as keys of the hash table,
//    we use buffers(existing hash values are not clobbered)
//  - this algorithm focuses on more optimal compression by storing
//    all offsets of a match(the hashtable can stores multiple
//    values for a key) and choosing one of the biggest matches
//    to copy from
//  - the number of buckets in the hash table is pre-estimated by
//    assuming an average line length of 17
//
// this is slow and was added more as a utility for testing
// 'patchDelta' and documenting git delta encoding format, so it
// should not be used indiscriminately
Uint8List diffDelta(Uint8List base, Uint8List target) {
  return base;
}

/*

func encodeInsertOperation(ibuf, buf *bytes.Buffer) {
	if ibuf.Len() == 0 {
		return
	}

	b := ibuf.Bytes()
	s := ibuf.Len()
	o := 0
	for {
		if s <= 127 {
			break
		}
		buf.WriteByte(byte(127))
		buf.Write(b[o : o+127])
		s -= 127
		o += 127
	}
	buf.WriteByte(byte(s))
	buf.Write(b[o : o+s])

	ibuf.Reset()
}

func encodeCopyOperation(offset, length int) []byte {
	code := 0x80
	var opcodes []byte

	var i uint
	for i = 0; i < 4; i++ {
		f := 0xff << (i * 8)
		if offset&f != 0 {
			opcodes = append(opcodes, byte(offset&f>>(i*8)))
			code |= 0x01 << i
		}
	}

	for i = 0; i < 3; i++ {
		f := 0xff << (i * 8)
		if length&f != 0 {
			opcodes = append(opcodes, byte(length&f>>(i*8)))
			code |= 0x10 << i
		}
	}

	return append([]byte{byte(code)}, opcodes...)
}

*/

/*
function diffDelta(source, target) {
  var block, matchOffsets, match, insertLength
    , i = 0
    , insertBuffer = new Buffer(127)
    , bufferedLength = 0
    , blocks = new Blocks(Math.ceil(source.length / 17))
    , opcodes = [];

  // first step is to encode the source and target sizes
  encodeHeader(opcodes, source.length, target.length);

  // now build the hashtable containing the lines/blocks
  while (i < source.length) {
    block = sliceBlock(source, i);
    blocks.set(block, i);
    i += block.length;
  }

  // now walk the target, looking for block matches
  i = 0;
  while (i < target.length) {
    block = sliceBlock(target, i);
    match = null;
    matchOffsets = blocks.get(block);
    if (matchOffsets)
      // choose the biggest match
      match = chooseMatch(source, matchOffsets, target, i);
    if (!match || match.length < MIN_COPY_LENGTH) {
      // this will happen when a match is not found or it is too short
      // either way we will insert or buffer data
      insertLength = block.length + (match ? match.length : 0);
      if (bufferedLength + insertLength <= insertBuffer.length) {
        // buffer as much data as permitted(127)
        target.copy(insertBuffer, bufferedLength, i, i + insertLength);
        bufferedLength += insertLength;
      } else {
        // emit insert for the buffered data
        emitInsert(opcodes, insertBuffer, bufferedLength);
        // start buffering again
        target.copy(insertBuffer, 0, i, i + insertLength);
        bufferedLength = insertLength;
      }
      i += insertLength;
    } else {
      if (bufferedLength) {
        // pending buffered data, flush it before copying
        emitInsert(opcodes, insertBuffer, bufferedLength);
        bufferedLength = 0;
      }
      emitCopy(opcodes, source, match.offset, match.length);
      i += match.length;
    }
  }

  if (bufferedLength) {
    // pending buffered
    emitInsert(opcodes, insertBuffer, bufferedLength);
    bufferedLength = 0;
  }

  // some assertion here won't hurt development
  if (i !== target.length) // TODO remove
    throw new Error('Error computing delta buffer');

  return new Buffer(opcodes);
}

*/

// function used to split buffers into blocks(units for matching regions
// in 'diffDelta')
List<int> sliceBlock(List<int> buffer, int pos) {
  var j = pos;

  // advance until a block boundary is found
  while (buffer[j] != 10 && (j - pos < 90) && j < buffer.length) {
    j++;
  }
  if (buffer[j] == 10) {
    j++;
  } // append the trailing linefeed to the block

  return buffer.sublist(pos, j);
}

// given a list of match offsets, this will choose the biggest one
_Match chooseMatch(List<int> source, List<int> sourcePositions,
    List<int> target, int targetPos) {
  int i, len, spos, tpos;
  int? rvLength;
  int? rvOffset;

  for (i = 0; i < sourcePositions.length; i++) {
    len = 0;
    spos = sourcePositions[i];
    tpos = targetPos;
    if (rvLength != null && rvOffset != null && spos < (rvOffset + rvLength)) {
      // this offset is contained in a previous match
      continue;
    }

    while (source[spos++] == target[tpos]) {
      len++;
      tpos++;
    }

    if (rvLength == null || rvOffset == null) {
      rvLength = len;
      rvOffset = sourcePositions[i];
    } else if (rvLength < len) {
      rvLength = len;
      rvOffset = sourcePositions[i];
    }
    if (rvLength > (source.length / 5).floor()) {
      // don't try to find a match that is bigger than one fifth of
      // the source buffer
      break;
    }
  }

  // Fimxe; Return rv
  return _Match(rvOffset, rvLength);
}

class _Match {
  int? offset;
  int? length;

  _Match(this.offset, this.length);
}

/*
// hashtable to store locations where a block of data appears in
// the source buffer. keys are Buffer instances(which contain the
// block data).
class _Block {
  var array = <int?>[];
  int n = 0;

  int? get(List<int> key) {
    var hashValue = _hash(key);
    var idx = hashValue % n;

    var a = array[idx];
    if (a != null) {
      return a.get(key);
    }

    return null;
  }

  void set(List<int> key, int value) {
    var hashValue = _hash(key);
    var idx = hashValue % n;

    var obj = array[idx];
    if (obj != null) {
      obj.set(key, value);
    } else {
      obj[idx] = _Bucket(key, value);
    }
  }
}

class _Bucket {
  int? key;
  List<int>? value;
}
*/

/*

// Bucket node for the above hashtable. it can store more than one
// value per key(since blocks can be repeated)
function Bucket(key, value) {
  this.key = key;
  this.value = [value];
}

Bucket.prototype.get = function(key) {
  var node = this;

  while (node && !compareBuffers(node.key, key))
    node = node.next;

  if (node)
    return node.value;
};

Bucket.prototype.set = function(key, value) {
  var node = this;

  while (!compareBuffers(node.key, key) && node.next)
    node = node.next;

  if (compareBuffers(node.key, key))
    // add more occurences of the block
    node.value.push(value);
  else
    // new block
    node.next = new Bucket(key, value);
};

function hash(buffer) {
  var w = 1
    , rv = 0
    , i = 0
    , j = buffer.length;

  while (i < j) {
    w *= 29;
    w = w & ((2 << 29) - 1);
    rv += buffer[i++] * w;
    rv = rv & ((2 << 29) - 1);
  }

  return rv;
}

function compareBuffers(a, b) {
  var i = 0;

  if (a.length !== b.length)
    return false;

  while (i < a.length && a[i] === b[i]) i++;

  if (i < a.length)
    return false;

  return true;
}

function Delta(source, target) {
  this.source = source;
  this.target = target;
}
*/

/*
int _hash(List<int> buffer) {
  var w = 1, rv = 0, i = 0, j = buffer.length;

  while (i < j) {
    w *= 29;
    w = w & ((2 << 29) - 1);
    rv += buffer[i++] * w;
    rv = rv & ((2 << 29) - 1);
  }

  return rv;
}
*/
// https://stackoverflow.com/questions/9478023/is-the-git-binary-diff-algorithm-delta-storage-standardized
