import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';

import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/idx_file.dart';
import 'package:dart_git/plumbing/object_types.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/plumbing/pack_file_delta.dart';

class PackFile {
  int numObjects;
  IdxFile idx;
  String filePath;

  static final int _headerSize = 16;

  PackFile.decode(this.idx, this.filePath, Uint8List headerBytes) {
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

  static Future<PackFile> fromFile(IdxFile idxFile, String filePath) async {
    var file = await File(filePath).open(mode: FileMode.read);
    var bytes = await file.read(_headerSize);
    await file.close();

    return PackFile.decode(idxFile, filePath, bytes);
  }

  // FIXME: Check the packFile hash from the idx?
  // FIXME: Verify that the crc32 is correct?

  Future<GitObject> object(GitHash hash) {
    // FIXME: The speed of this can be improved by using the fanout table
    var i = idx.entries.indexWhere((e) => e.hash == hash);
    if (i == -1) {
      return null;
    }

    var entry = idx.entries[i];
    return _getObject(entry.offset);
  }

  Future<GitObject> _getObject(int offset) async {
    var file = await File(filePath).open();
    await file.setPosition(offset);

    var headByte = await file.readByte();
    var type = (0x70 & headByte) >> 4;

    var needMore = (0x80 & headByte) > 0;

    // the length is codified in the last 4 bits of the first byte and in
    // the last 7 bits of subsequent bytes.  Last byte has a 0 MSB.
    var size = (headByte & 0xf);
    var bitsToShift = 4;

    while (needMore) {
      var headByte = await file.readByte();

      needMore = (0x80 & headByte) > 0;
      size += ((headByte & 0x7f) << bitsToShift);
      bitsToShift += 7;
    }

    var objHeader = PackObjectHeader(size, type, offset);

    // Construct the PackObject
    switch (objHeader.type) {
      case ObjectTypes.OFS_DELTA:
        var n = await _readVariableWidthInt(file);
        var baseOffset = offset - n;
        var deltaData = await _decodeObject(file, objHeader.size);

        return _fillOFSDeltaObject(baseOffset, deltaData);

      case ObjectTypes.REF_DELTA:
        throw Exception('OFS_REF_DELTA not supported');

      /*
        var hashBytes = await file.read(20);
        var hash = GitHash.fromBytes(hashBytes);

        return _fillRefDeltaObject(hash, objHeader, rawObjData);
        */
      default:
        break;
    }

    // The objHeader.size is the size of the data once expanded
    var rawObjData = await _decodeObject(file, objHeader.size);
    await file.close();

    var typeStr = ObjectTypes.getTypeString(objHeader.type);
    return createObject(typeStr, rawObjData);
  }

  Future<List<int>> _decodeObject(RandomAccessFile file, int objSize) async {
    var compressedData = <int>[];

    while (true) {
      // The number 512 is chosen since the block size is generally 512
      // The dart zlib parser doesn't have a way to greedily keep reading
      // till it reaches a certain size
      compressedData.addAll(await file.read(objSize + 512));
      var decodedData = zlib.decode(compressedData);
      if (decodedData.length >= objSize) {
        return decodedData.sublist(0, objSize);
      }
    }
  }

  Future<GitObject> _fillOFSDeltaObject(
      int baseOffset, List<int> deltaData) async {
    var baseObject = await _getObject(baseOffset);
    var deltaObj = patchDelta(baseObject.serializeData(), deltaData);

    return createObject(ascii.decode(baseObject.format()), deltaObj);
  }

  /*
  Future<GitObject> _fillRefDeltaObject(
      GitHash hash, PackObjectHeader objHeader, List<int> deltaData) async {
    var typeStr = ObjectTypes.getTypeString(objHeader.type);

    return createObject(typeStr, rawData);
  }
  */

  Future<Iterable<GitObject>> getAll() async {
    var objects = <GitObject>[];

    for (var i = 0; i < idx.entries.length; i++) {
      var entry = idx.entries[i];

      var obj = await _getObject(entry.offset);

      assert(obj.hash() == entry.hash);
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

// ReadVariableWidthInt reads and returns an int in Git VLQ special format:
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

final _maskContinue = 128; // 1000 000
final _maskLength = 127; // 0111 1111
final _lengthBits = 7; // subsequent bytes has 7 bits to store the length

Future<int> _readVariableWidthInt(RandomAccessFile file) async {
  var c = await file.readByte();

  var v = (c & _maskLength);
  while (c & _maskContinue > 0) {
    v++;

    c = await file.readByte();

    v = (v << _lengthBits) + (c & _maskLength);
  }

  return v;
}
