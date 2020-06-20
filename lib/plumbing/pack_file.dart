import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/object_types.dart';

class PackFile {
  int numObjects;
  List<GitObject> objects = [];

  PackFile.decode(Iterable<int> bytes) {
    var reader = ByteDataReader(endian: Endian.big, copy: false);
    reader.add(bytes);

    var totalNumBytes = bytes.length;

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

    // Number of Objects
    var numObjects = reader.readUint32();
    this.numObjects = numObjects;

    // Read all the objects
    for (var i = 0; i < numObjects; i++) {
      var objectStartoffset = reader.remainingLength - totalNumBytes;
      var headByte = reader.readUint8();
      var type = (0x70 & headByte) >> 4;
      var needMore = (0x80 & headByte) > 0;

      var size = (headByte & 0xf);
      var bitsToShift = 4;

      while (needMore) {
        var headByte = reader.readUint8();
        needMore = (0x80 & headByte) > 0;
        size |= ((headByte & 0x7f) << bitsToShift);
        bitsToShift += 7;
      }

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
      print('Object size $size');

      var typeStr = ObjectTypes.getTypeString(objHeader.type);
      print('Trying to read object of type $typeStr');

      var compressedData = reader.read(objHeader.size);
      var rawObjData = zlib.decode(compressedData);
      var object = createObject(typeStr, rawObjData);

      print('Read object of type $typeStr');
      print(object.hash());
      if (object is GitCommit) {
        print(object.author);
      }
      objects.add(object);
    }
  }

  GitObject getObject(GitHash hash) {
    return GitCommit([], null);
  }

  Iterable<GitObject> getAll() {
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
