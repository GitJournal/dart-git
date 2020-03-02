import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:buffer/buffer.dart';
import 'package:dart_git/git_hash.dart';

class GitIndex {
  int versionNo;
  int fileSize;
  var entries = <GitIndexEntry>[];

  GitIndex.decode(List<int> bytes) {
    var reader = ByteDataReader(endian: Endian.big, copy: false);
    reader.add(bytes);
    fileSize = bytes.length;

    // Read 12 byte header
    var sig = reader.read(4);
    if (sig.length != 4) {
      throw Exception('GitIndexCorrupted: Invalid Signature lenght');
    }

    var expectedSig = ascii.encode('DIRC');
    Function eq = const ListEquality().equals;
    if (!eq(sig, expectedSig)) {
      throw Exception('GitIndexCorrupted: Invalid signature $sig');
    }

    versionNo = reader.readUint32();
    if (versionNo <= 1 || versionNo >= 4) {
      throw Exception('GitIndexError: Version number not supported $versionNo');
    }

    // Read Index Entries
    var numEntries = reader.readUint32();
    for (var i = 0; i < numEntries; i++) {
      var entry = GitIndexEntry(this, reader);
      entries.add(entry);
    }

    //
  }
}

class GitIndexEntry {
  GitIndex index;

  //static int _objectTypeFile = int.parse('1000', radix: 2);
  //static int _objectTypeSymbolicLink = int.parse('1010', radix: 2);
  //static int _objectTypeGitLink = int.parse('1110', radix: 2);

  int ctimeSeconds;
  int ctimeNanoSeconds;

  int mtimeSeconds;
  int mtimeNanoSeconds;

  int dev;
  int ino;

  // mode
  int mode;
  //int objectType;

  GitHash hash;
  String relativeFilePath;

  int uid;
  int gid;

  int size;
  List<int> sha;

  int flags;
  int extraFlags;

  String path;

  GitIndexEntry(this.index, ByteDataReader reader) {
    var startingBytes = index.fileSize - reader.remainingLength;

    ctimeSeconds = reader.readUint32();
    ctimeNanoSeconds = reader.readUint32();

    mtimeSeconds = reader.readUint32();
    mtimeNanoSeconds = reader.readUint32();

    dev = reader.readUint32();
    ino = reader.readUint32();

    // Mode
    mode = reader.readUint32(); // FIXME: We should parse the mode

    uid = reader.readUint32();
    gid = reader.readUint32();

    size = reader.readUint32();
    hash = GitHash.fromBytes(reader.read(20));

    flags = reader.readUint16();
    const hasExtendedFlag = 0x4000;
    if (flags & hasExtendedFlag != 0) {
      if (index.versionNo <= 2) {
        throw Exception('Index version 2 must not have an extended flag');
      }
      extraFlags = reader.readUint16();
    }

    // Read name
    switch (index.versionNo) {
      case 2:
      case 3:
        const nameMask = 0xfff;
        var len = flags & nameMask;
        path = utf8.decode(reader.read(len));
        break;

      case 4:
      default:
        throw Exception('Index version not supported');
    }

    // Discard Padding
    if (index.versionNo == 4) {
      return;
    }
    var endingBytes = index.fileSize - reader.remainingLength;
    var entrySize = endingBytes - startingBytes;
    var padLength = 8 - (entrySize % 8);
    reader.read(padLength);
  }
}
