import 'dart:convert';
import 'dart:io' show zlib;
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:file/file.dart';

import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/idx_file.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/plumbing/pack_file_delta.dart';
import 'package:dart_git/utils/bytes_data_reader.dart';
import 'package:meta/meta.dart';

class PackFile {
  int numObjects = 0;
  IdxFile idx;
  FileSystem fs;

  RandomAccessFile file;

  static final int _headerSize = 16;

  PackFile.decode({
    required this.idx,
    required this.file,
    required Uint8List headerBytes,
    required this.fs,
  }) {
    assert(headerBytes.length == _headerSize);

    var reader = ByteDataReader(endian: Endian.big, copy: false);
    reader.add(headerBytes);

    // Read the signature
    var sigBytes = reader.read(4);
    if (sigBytes.length != 4) {
      throw Exception('GitPackFileCorrupted: Invalid Signature length');
    }

    var sig = ascii.decode(sigBytes);
    if (sig != 'PACK') {
      throw Exception('GitPackFileCorrupted: Invalid signature $sig');
    }

    // Version
    var version = reader.readUint32();
    if (version != 2) {
      throw Exception('GitPackFileCorrupted: Unsupported version: $version');
    }

    numObjects = reader.readUint32();
  }

  static PackFile fromFile(
    IdxFile idxFile,
    String filePath,
    FileSystem fs,
  ) {
    var file = fs.file(filePath).openSync(mode: FileMode.read);
    var bytes = file.readSync(_headerSize);

    return PackFile.decode(
      idx: idxFile,
      file: file,
      headerBytes: bytes,
      fs: fs,
    );
  }

  GitObject? object(GitHash hash) {
    var obj = _objectByHash(hash);
    if (obj == null) return null;

    return createObject(obj.type, obj.data, hash);
  }

  // FIXME: Check the packFile hash from the idx?
  // FIXME: Verify that the crc32 is correct?

  RawObject? _objectByHash(GitHash hash) {
    var entry = idx.entry(hash);
    if (entry == null) return null;

    return _objectByOffset(entry.offset);
  }

  RawObject? _objectByOffset(int offset) {
    file.setPositionSync(offset);

    var headByte = file.readByteSync();
    var type = (0x70 & headByte) >> 4;

    var needMore = (0x80 & headByte) > 0;

    // the length is codified in the last 4 bits of the first byte and in
    // the last 7 bits of subsequent bytes.  Last byte has a 0 MSB.
    var size = headByte & 0xf;
    var bitsToShift = 4;

    while (needMore) {
      var headByte = file.readByteSync();

      needMore = (0x80 & headByte) > 0;
      size += (headByte & 0x7f) << bitsToShift;
      bitsToShift += 7;
    }

    var objHeader = PackObjectHeader(size, type, offset);

    // Construct the PackObject
    switch (objHeader.type) {
      case ObjectTypes.OFS_DELTA:
        var n = file.readVariableWidthIntSync();
        var baseOffset = offset - n;
        var deltaData = _decodeObject(file, objHeader.size);

        return _fillOFSDeltaObject(baseOffset, deltaData);

      case ObjectTypes.REF_DELTA:
        var hashBytes = file.readSync(20);
        var hash = GitHash.fromBytes(hashBytes);
        var deltaData = _decodeObject(file, objHeader.size);

        return _fillRefDeltaObject(hash, deltaData);

      default:
        break;
    }

    // The objHeader.size is the size of the data once expanded
    var rawObjData = _decodeObject(file, objHeader.size);
    return RawObject(data: rawObjData, type: objHeader.type);
  }

  static Uint8List _decodeObject(RandomAccessFile file, int objSize) {
    // The number 512 is chosen since the block size is generally 512
    // We need to keep reading until we have decompressed enough bytes.
    // Compressed data can have unpredictable ratios, so we may need
    // to read more than objSize compressed bytes to get objSize decompressed bytes.
    var outputSink = _BufferSink();
    var inputSink = zlib.decoder.startChunkedConversion(outputSink);

    var readChunk = 512;
    var totalRead = 0;

    // Keep reading until we have enough decompressed data
    while (outputSink.builder.length < objSize) {
      var bytes = file.readSync(readChunk);
      if (bytes.isEmpty) break; // EOF reached
      totalRead += bytes.length;
      inputSink.add(bytes);
    }
    inputSink.close();

    if (outputSink.builder.length < objSize) {
      throw Exception('PackFile._decodeObject: Failed to decompress object. '
          'Expected $objSize bytes, got ${outputSink.builder.length}. '
          'Read $totalRead compressed bytes.');
    }
    return outputSink.builder.takeBytes();
  }

  RawObject? _fillOFSDeltaObject(int baseOffset, Uint8List deltaData) {
    var baseObject = _objectByOffset(baseOffset);
    if (baseObject == null) {
      return null;
    }

    var deltaObj = patchDelta(baseObject.data, deltaData);
    return RawObject(data: deltaObj, type: baseObject.type);
  }

  RawObject? _fillRefDeltaObject(GitHash baseHash, Uint8List deltaData) {
    var baseObject = _objectByHash(baseHash);
    if (baseObject == null) {
      return null;
    }
    var deltaObj = patchDelta(baseObject.data, deltaData);
    return RawObject(data: deltaObj, type: baseObject.type);
  }

  Iterable<GitObject> getAll() {
    var objects = <GitObject>[];

    for (var i = 0; i < idx.entries.length; i++) {
      var entry = idx.entries[i];

      var rawObj = _objectByOffset(entry.offset);
      if (rawObj == null) {
        continue;
      }

      var obj = createObject(rawObj.type, rawObj.data, entry.hash);
      assert(obj.hash == entry.hash);
      objects.add(obj);
    }

    return objects;
  }

  void close() {
    file.closeSync();
  }

  // hash() of this Packfile
  // getAllObjects()
  // getByType()
  //
}

@immutable
class RawObject {
  final Uint8List data;
  final int type;

  RawObject({required this.data, required this.type});
}

@immutable
class PackObjectHeader {
  final int size;
  final int type;
  final int offset;

  PackObjectHeader(this.size, this.type, this.offset);

  @override
  String toString() =>
      'PackObjectHeader{size: $size, type: $type, offset: $offset}';
}

int _roundUp(int numToRound, int multiple) {
  assert(multiple != 0);
  return ((numToRound + multiple - 1) ~/ multiple) * multiple;
}

// Copied from dart-sdk io
class _BufferSink extends ByteConversionSink {
  final BytesBuilder builder = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    builder.add(chunk);
  }

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    if (chunk is Uint8List) {
      Uint8List list = chunk;
      builder.add(
          Uint8List.view(list.buffer, list.offsetInBytes + start, end - start));
    } else {
      builder.add(chunk.sublist(start, end));
    }
  }

  @override
  void close() {}
}
