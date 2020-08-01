import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:dart_git/git_hash.dart';

class IdxFile {
  var entries = <IdxFileEntry>[];
  var fanTable = Uint32List(_FAN_TABLE_LENGTH);
  GitHash packFileHash;

  static const _PACK_IDX_SIGNATURE = 0xff744f63;
  static const _PACK_VERSION = 2;
  static const _FAN_TABLE_LENGTH = 256;

  IdxFile.decode(Iterable<int> bytes) {
    var allBytes = bytes.toList();
    var reader = ByteDataReader(endian: Endian.big, copy: false);
    reader.add(allBytes);

    // Read the signature
    var sig = reader.readUint32();
    if (sig != _PACK_IDX_SIGNATURE) {
      throw Exception('GitIdxFileCorrupted: Invalid signature $sig');
    }

    // Version
    var version = reader.readUint32();
    if (version != _PACK_VERSION) {
      throw Exception('GitIdxFileCorrupted: Unsupported version: $version');
    }

    // Fanout Table
    for (var i = 0; i < _FAN_TABLE_LENGTH; i++) {
      fanTable[i] = reader.readUint32();
    }
    var numObjects = fanTable.last;

    // Read Hashes
    var hashes = List<GitHash>(numObjects);
    for (var i = 0; i < numObjects; i++) {
      var hash = GitHash.fromBytes(reader.read(20));

      hashes[i] = hash;
    }

    // Read crc32
    var crcValues = List<int>(numObjects);
    for (var i = 0; i < numObjects; i++) {
      crcValues[i] = reader.readUint32();
    }

    // Read offsets
    var offsets = List<int>(numObjects);
    var offset64BitPos = <int>[];
    for (var i = 0; i < numObjects; i++) {
      offsets[i] = reader.readUint32();

      // MSB is 1
      var msbSet = offsets[i] & 0x80000000;
      if (msbSet > 0) {
        offset64BitPos.add(i);
      }
    }

    // 64-bit offsets
    for (var i = 0; i < offset64BitPos.length; i++) {
      var pos = offset64BitPos[i];
      var offset = reader.readUint64();

      offsets[pos] = offset;
    }

    packFileHash = GitHash.fromBytes(reader.read(20));

    var bytesRead = reader.offsetInBytes;
    var idxFileHash = GitHash.fromBytes(reader.read(20));
    var fileHash = GitHash.compute(allBytes.sublist(0, bytesRead));
    if (fileHash != idxFileHash) {
      throw Exception('GitIdxFileCorrupted: Invalid file hash');
    }

    if (reader.remainingLength != 0) {
      throw Exception('GitIdxFileCorrupted: Extra bytes in the end');
    }

    entries = List<IdxFileEntry>(numObjects);
    for (var i = 0; i < numObjects; i++) {
      entries[i] = IdxFileEntry(
        hash: hashes[i],
        crc32: crcValues[i],
        offset: offsets[i],
      );
    }
  }

  Iterable<int> encode() {
    assert(false);
    return [];
  }
}

class IdxFileEntry extends Equatable {
  final GitHash hash;
  final int crc32;
  final int offset;

  IdxFileEntry({
    @required this.hash,
    @required this.crc32,
    @required this.offset,
  });

  @override
  List<Object> get props => [hash, offset, crc32];

  @override
  bool get stringify => true;
}
