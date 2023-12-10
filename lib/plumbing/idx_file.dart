import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:equatable/equatable.dart';

import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/utils/uint8list.dart';
import 'package:meta/meta.dart';

@immutable
class IdxFile {
  late final List<IdxFileEntry> entries;
  final fanTable = Uint32List(_FAN_TABLE_LENGTH);
  late final GitHash packFileHash;

  static const _PACK_IDX_SIGNATURE = 0xff744f63;
  static const _PACK_VERSION = 2;
  static const _FAN_TABLE_LENGTH = 256;

  IdxFile.decode(Uint8List bytes) {
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
    var hashes = List<GitHash>.filled(numObjects, GitHash.zero());
    for (var i = 0; i < numObjects; i++) {
      var hash = GitHash.fromBytes(reader.read(20));

      hashes[i] = hash;
    }

    // Read crc32
    var crcValues = List<int>.filled(numObjects, 0);
    for (var i = 0; i < numObjects; i++) {
      crcValues[i] = reader.readUint32();
    }

    // Read offsets
    var offsets = List<int>.filled(numObjects, 0);
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
    var fileHash = GitHash.compute(bytes.sublistView(0, bytesRead));
    if (fileHash != idxFileHash) {
      throw Exception('GitIdxFileCorrupted: Invalid file hash');
    }

    if (reader.remainingLength != 0) {
      throw Exception('GitIdxFileCorrupted: Extra bytes in the end');
    }

    entries = List<IdxFileEntry>.generate(numObjects, (i) {
      return IdxFileEntry(
        hash: hashes[i],
        crc32: crcValues[i],
        offset: offsets[i],
      );
    });
  }

  Uint8List encode() {
    var writer = ByteDataWriter();

    writer.writeUint32(_PACK_IDX_SIGNATURE);
    writer.writeUint32(_PACK_VERSION);

    // Fanout Table
    for (var i = 0; i < _FAN_TABLE_LENGTH; i++) {
      writer.writeUint32(fanTable[i]);
    }

    // Write Hashes
    for (var entry in entries) {
      writer.write(entry.hash.bytes);
    }

    // Write crc32
    for (var entry in entries) {
      writer.writeUint32(entry.crc32);
    }

    // Write offsets
    var offset64BitPos = <int>[];
    for (var i = 0; i < entries.length; i++) {
      var o = entries[i].offset;

      if (o > 0x7FFFFFFF) {
        writer.writeUint32(0x80000000 + offset64BitPos.length);
        offset64BitPos.add(o);
      } else {
        writer.writeUint32(o);
      }
    }

    for (var o in offset64BitPos) {
      writer.writeUint64(o);
    }

    writer.write(packFileHash.bytes);

    var idxFileHash = GitHash.compute(writer.toBytes());
    writer.write(idxFileHash.bytes);

    return writer.toBytes();
  }

  IdxFileEntry? entry(GitHash hash) {
    var firstByte = hash.bytes[0];
    var lowerBound = firstByte == 0 ? 0 : fanTable[firstByte - 1];
    var upperBound = fanTable[firstByte];

    // The number of objects with prefix `firstByte`
    // https://alibabacloud.com/blog/a-detailed-explanation-of-the-underlying-data-structures-and-principles-of-git_597391
    if (upperBound - lowerBound == 0) {
      return null;
    }

    var i = _binarySearch(entries, hash, lowerBound, upperBound);
    if (i == -1) return null;
    return entries[i];
  }
}

// Adapated from package collections/algorithm
int _binarySearch(
  List<IdxFileEntry> list,
  GitHash value,
  int start,
  int end,
) {
  end = RangeError.checkValidRange(start, end, list.length);
  var min = start;
  var max = end;
  while (min < max) {
    var mid = min + ((max - min) >> 1);
    var element = list[mid];
    var comp = element.compareTo(value);

    if (comp == 0) return mid;
    if (comp < 0) {
      min = mid + 1;
    } else {
      max = mid;
    }
  }
  return -1;
}

@immutable
class IdxFileEntry extends Equatable implements Comparable {
  final GitHash hash;
  final int crc32;
  final int offset;

  IdxFileEntry({
    required this.hash,
    required this.crc32,
    required this.offset,
  });

  @override
  List<Object> get props => [hash, offset, crc32];

  @override
  bool get stringify => true;

  @override
  int compareTo(dynamic other) {
    if (other is GitHash) {
      return hash.compareTo(other);
    }
    if (other is IdxFileEntry) {
      return hash.compareTo(other.hash);
    }
    throw Exception(
        'Other ${other.runtimeType} cannot be compared with IdxFileEntry');
  }

  @override
  bool operator ==(Object other) {
    if (other is GitHash) return other == hash;
    if (other is! IdxFileEntry) return false;

    return hash == other.hash && crc32 == other.crc32 && offset == other.offset;
  }

  @override
  int get hashCode => Object.hashAll([hash, crc32, offset]);
}
