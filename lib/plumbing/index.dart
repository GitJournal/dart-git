import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:buffer/buffer.dart';
import 'package:equatable/equatable.dart';

import 'package:dart_git/git_hash.dart';

class GitIndex {
  int versionNo;
  int fileSize;
  var entries = <GitIndexEntry>[];

  List<TreeEntry> cache = []; // cached tree extension

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

    // Read Extensions
    List<int> extensionHeader;
    while (true) {
      extensionHeader = reader.read(4);
      if (!_parseExtension(extensionHeader, reader)) {
        break;
      }
    }

    var hashBytes = [...extensionHeader, ...reader.read(16)];
    var expectedHash = GitHash.fromBytes(hashBytes);
    var actualHash = GitHash.compute(
        bytes.sublist(0, bytes.length - 20)); // FIXME: Avoid this copy!
    if (expectedHash != actualHash) {
      print('ExpctedHash: $expectedHash');
      print('ActualHash:  $actualHash');
      throw Exception('Index file seems to be corrupted');
    }
  }

  bool _parseExtension(List<int> header, ByteDataReader reader) {
    final treeHeader = ascii.encode('TREE');
    final reucHeader = ascii.encode('REUC');
    final eoicHeader = ascii.encode('EOIC');

    if (_listEq(header, treeHeader)) {
      var length = reader.readUint32();
      var data = reader.read(length);
      _parseCacheTreeExtension(data);
      return true;
    }

    if (_listEq(header, reucHeader) || _listEq(header, eoicHeader)) {
      var length = reader.readUint32();
      var data = reader.read(length); // Ignoring the data for now
      return true;
    }

    return false;
  }

  void _parseCacheTreeExtension(Uint8List data) {
    final space = ' '.codeUnitAt(0);
    final newLine = '\n'.codeUnitAt(0);

    var pos = 0;
    while (pos < data.length) {
      var pathEndPos = data.indexOf(0, pos);
      if (pathEndPos == -1) {
        throw Exception('Git Cache Index corrupted');
      }
      var path = data.sublist(pos, pathEndPos);
      pos = pathEndPos + 1;

      var entryCountEndPos = data.indexOf(space, pos);
      if (entryCountEndPos == -1) {
        throw Exception('Git Cache Index corrupted');
      }
      var entryCount = data.sublist(pos, entryCountEndPos);
      pos = entryCountEndPos + 1;
      assert(data[pos - 1] == space);

      var numEntries = int.parse(ascii.decode(entryCount));
      if (numEntries == -1) {
        // Invalid entry
        continue;
      }

      var numSubtreeEndPos = data.indexOf(newLine, pos);
      if (numSubtreeEndPos == -1) {
        throw Exception('Git Cache Index corrupted');
      }
      var numSubTree = data.sublist(pos, numSubtreeEndPos);
      pos = numSubtreeEndPos + 1;
      assert(data[pos - 1] == newLine);

      var hashBytes = data.sublist(pos, pos + 20);
      pos += 20;

      var treeEntry = TreeEntry(
        path: utf8.decode(path),
        numEntries: numEntries,
        numSubTrees: int.parse(ascii.decode(numSubTree)),
        hash: GitHash.fromBytes(hashBytes),
      );
      cache.add(treeEntry);
    }
  }

  List<int> serialize() {
    return [];
  }

  static final Function _listEq = const ListEquality().equals;
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

  List<int> serialize() {
    var writer = ByteDataWriter(endian: Endian.big);

    writer.writeUint32(ctimeSeconds);
    writer.writeUint32(ctimeNanoSeconds);

    writer.writeUint32(mtimeSeconds);
    writer.writeUint32(mtimeNanoSeconds);

    writer.writeUint32(dev);
    writer.writeUint32(ino);

    writer.writeUint32(mode);

    writer.writeUint32(uid);
    writer.writeUint32(gid);
    writer.writeUint32(size);

    writer.write(hash.bytes);

    // Flags
    // FIXME: Flags need to be generated based on name length
    writer.writeUint16(flags);

    // FIXME: Write the name
    // FIXME: Add padding depending on the version

    return writer.toBytes();
  }
}

class TreeEntry extends Equatable {
  final String path;
  final int numEntries;
  final int numSubTrees;
  final GitHash hash;

  const TreeEntry({this.path, this.numEntries, this.numSubTrees, this.hash});

  @override
  List<Object> get props => [path, numEntries, numSubTrees, hash];

  @override
  bool get stringify => true;
}
