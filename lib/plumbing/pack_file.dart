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

class PackFile {
  int numObjects = 0;
  IdxFile idx;
  String filePath;
  FileSystem fs;

  static final int _headerSize = 16;

  // FIXME: BytesDataReader can throw a range error!
  PackFile.decode({
    required this.idx,
    required this.filePath,
    required Uint8List headerBytes,
    required this.fs,
  }) {
    assert(headerBytes.length == _headerSize);

    var reader = ByteDataReader(endian: Endian.big, copy: false);
    reader.add(headerBytes);

    // Read the signature
    var sigBytes = reader.read(4);
    if (sigBytes.length != 4) {
      throw Exception('GitPackFileCorrupted: Invalid Signature lenght');
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

  static Future<PackFile> fromFile(
    IdxFile idxFile,
    String filePath,
    FileSystem fs,
  ) async {
    var file = fs.file(filePath).openSync(mode: FileMode.read);
    var bytes = await file.read(_headerSize);
    await file.close();

    return PackFile.decode(
      idx: idxFile,
      filePath: filePath,
      headerBytes: bytes,
      fs: fs,
    );
  }

  // FIXME: Check the packFile hash from the idx?
  // FIXME: Verify that the crc32 is correct?

  Future<GitObject?> object(GitHash hash) async {
    var entry = idx.entry(hash);
    if (entry == null) return null;

    return _getObject(entry.offset);
  }

  Future<GitObject?> _getObject(int offset) async {
    var file = fs.file(filePath).openSync(mode: FileMode.read);
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
        var deltaData = await _decodeObject(file, objHeader.size);

        await file.close();
        return _fillOFSDeltaObject(baseOffset, deltaData);

      case ObjectTypes.REF_DELTA:
        var hashBytes = await file.read(20);
        var hash = GitHash.fromBytes(hashBytes);
        var deltaData = await _decodeObject(file, objHeader.size);

        await file.close();
        return _fillRefDeltaObject(hash, deltaData);

      default:
        break;
    }

    // The objHeader.size is the size of the data once expanded
    var rawObjData = await _decodeObject(file, objHeader.size);
    await file.close();

    var typeStr = ObjectTypes.getTypeString(objHeader.type);
    return createObject(typeStr, rawObjData).getOrThrow();
  }

  Future<Uint8List> _decodeObject(RandomAccessFile file, int objSize) async {
    // FIXME: This is crashing in Sentry -
    // https://sentry.io/organizations/gitjournal/issues/2254310735/?project=5168082&query=is%3Aunresolved
    // - I'm getting there is a huge object cloned and we're loading all of
    //   it into memory.
    //   A proper fix might be to never give back the data, only a way to read it
    //   -> Just use streams?
    //

    // The number 512 is chosen since the block size is generally 512
    // The dart zlib parser doesn't have a way to greedily keep reading
    // till it reaches a certain size
    var readSize = _roundUp(objSize, 512);

    var outputSink = _BufferSink();
    var inputSink = zlib.decoder.startChunkedConversion(outputSink);
    inputSink.add(await file.read(readSize));
    inputSink.close();

    assert(outputSink.builder.length >= objSize);
    return outputSink.builder.takeBytes();
  }

  Future<GitObject?> _fillOFSDeltaObject(
      int baseOffset, Uint8List deltaData) async {
    var baseObject = await _getObject(baseOffset);
    if (baseObject == null) {
      return null;
    }
    var deltaObj = patchDelta(baseObject.serializeData(), deltaData);

    return createObject(ascii.decode(baseObject.format()), deltaObj)
        .getOrThrow();
  }

  Future<GitObject?> _fillRefDeltaObject(
      GitHash baseHash, Uint8List deltaData) async {
    var baseObject = await object(baseHash);
    if (baseObject == null) {
      return null;
    }
    var deltaObj = patchDelta(baseObject.serializeData(), deltaData);

    return createObject(ascii.decode(baseObject.format()), deltaObj)
        .getOrThrow();
  }

  Future<Iterable<GitObject>> getAll() async {
    var objects = <GitObject>[];

    for (var i = 0; i < idx.entries.length; i++) {
      var entry = idx.entries[i];

      var obj = await _getObject(entry.offset);
      if (obj == null) {
        continue;
      }
      assert(obj.hash == entry.hash);
      objects.add(obj);
    }

    return objects;
  }

  // hash() of this Packfile
  // getAllObjects()
  // getByType()
  //
}

// class PackedObject?

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
