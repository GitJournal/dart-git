import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/idx_file.dart';
import 'package:dart_git/plumbing/object_types.dart';

class PackFile {
  int numObjects;
  IdxFile idx;
  String filePath;

  PackFile.decode(this.idx, this.filePath) {
    // FIXME: This is terrible for performance, it is reading the entire huge
    //        as PackFile into memory
    var bytes = File(filePath).readAsBytesSync();

    var reader = ByteDataReader(endian: Endian.big, copy: false);
    reader.add(bytes);

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

  Future<GitObject> _getObject(int offset) async {
    var file = await File(filePath).open();
    await file.setPosition(offset);

    var headByte = (await file.read(1))[0];
    var type = (0x70 & headByte) >> 4;

    var needMore = (0x80 & headByte) > 0;

    // the length is codified in the last 4 bits of the first byte and in
    // the last 7 bits of subsequent bytes.  Last byte has a 0 MSB.
    var size = (headByte & 0xf);
    var bitsToShift = 4;

    while (needMore) {
      var headByte = (await file.read(1))[0];

      needMore = (0x80 & headByte) > 0;
      size += ((headByte & 0x7f) << bitsToShift);
      bitsToShift += 7;
    }

    var objectStartoffset = offset;
    var objHeader = PackObjectHeader(size, type, objectStartoffset);

    // Construct the PackObject
    switch (objHeader.type) {
      case ObjectTypes.OFS_DELTA:
        throw Exception('OFS_DELTA not supported');
        //object.desiredOffset = findDeltaBaseOffset(header);
        break;
      case ObjectTypes.REF_DELTA:
        throw Exception('OFS_REF_DELTA not supported');
        break;
      default:
        break;
    }

    var typeStr = ObjectTypes.getTypeString(objHeader.type);

    // The objHeader.size is the size of the data once expanded
    // FIXME: Do not hardcode this 100
    var compressedData = await file.read(objHeader.size + 100);
    await file.close();

    var rawObjData = zlib.decode(compressedData).sublist(0, objHeader.size);
    return createObject(typeStr, rawObjData);
  }

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
}
