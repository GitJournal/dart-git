import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'package:dart_git/ascii_helper.dart';
import 'package:dart_git/git_hash.dart';

class GitIndex {
  int versionNo;
  var entries = <GitIndexEntry>[];

  List<TreeEntry> cache = []; // cached tree extension

  GitIndex({@required this.versionNo});

  GitIndex.decode(List<int> bytes) {
    var reader = ByteDataReader(endian: Endian.big, copy: false);
    reader.add(bytes);

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
      var entry = GitIndexEntry.fromBytes(versionNo, bytes.length, reader);
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
    var pos = 0;
    while (pos < data.length) {
      var pathEndPos = data.indexOf(0, pos);
      if (pathEndPos == -1) {
        throw Exception('Git Cache Index corrupted');
      }
      var path = data.sublist(pos, pathEndPos);
      pos = pathEndPos + 1;

      var entryCountEndPos = data.indexOf(asciiHelper.space, pos);
      if (entryCountEndPos == -1) {
        throw Exception('Git Cache Index corrupted');
      }
      var entryCount = data.sublist(pos, entryCountEndPos);
      pos = entryCountEndPos + 1;
      assert(data[pos - 1] == asciiHelper.space);

      var numEntries = int.parse(ascii.decode(entryCount));
      if (numEntries == -1) {
        // Invalid entry
        continue;
      }

      var numSubtreeEndPos = data.indexOf(asciiHelper.newLine, pos);
      if (numSubtreeEndPos == -1) {
        throw Exception('Git Cache Index corrupted');
      }
      var numSubTree = data.sublist(pos, numSubtreeEndPos);
      pos = numSubtreeEndPos + 1;
      assert(data[pos - 1] == asciiHelper.newLine);

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
    // Do we support this version of the index?
    if (versionNo != 2) {
      throw Exception('Git Index version $versionNo cannot be serialized');
    }

    var writer = ByteDataWriter();

    // Header
    writer.write(ascii.encode('DIRC'));
    writer.writeUint32(versionNo);
    writer.writeUint32(entries.length);

    // Entries
    entries.sort((a, b) => a.path.compareTo(b.path));
    entries.forEach((e) => writer.write(e.serialize()));

    // Footer
    var hash = GitHash.compute(writer.toBytes());
    writer.write(hash.bytes);

    return writer.toBytes();
  }

  static final Function _listEq = const ListEquality().equals;

  void addPath(String path) async {
    var stat = await FileStat.stat(path);

    var bytes = await File(path).readAsBytes();
    var hash = GitHash.compute(bytes);
    var entry = GitIndexEntry.fromFS(path, stat, hash);
    entries.add(entry);
  }
}

class GitIndexEntry {
  DateTime cTime;
  DateTime mTime;

  int dev;
  int ino;

  GitFileMode mode;

  int uid;
  int gid;

  int fileSize;
  GitHash hash;

  GitFileStage stage;

  String path;

  GitIndexEntry({
    @required this.cTime,
    @required this.mTime,
    @required this.dev,
    @required this.ino,
    @required this.mode,
    @required this.uid,
    @required this.gid,
    @required this.fileSize,
    @required this.hash,
    this.stage = GitFileStage.Merged,
    @required this.path,
  });

  GitIndexEntry.fromFS(String path, FileStat stat, GitHash hash) {
    cTime = stat.changed;
    mTime = stat.modified;
    mode = GitFileMode(stat.mode);

    // These don't seem to be exposed in Dart
    ino = 0;
    dev = 0;

    switch (stat.type) {
      case FileSystemEntityType.file:
        mode = GitFileMode.Regular;
        break;
      case FileSystemEntityType.directory:
        mode = GitFileMode.Dir;
        break;
      case FileSystemEntityType.link:
        mode = GitFileMode.Symlink;
        break;
    }

    // Don't seem accessible in Dart -https://github.com/dart-lang/sdk/issues/15078
    uid = 0;
    gid = 0;

    fileSize = stat.size;
    this.hash = hash;
    this.path = path;

    stage = GitFileStage(0);

    assert(!path.startsWith('/'));
  }

  GitIndexEntry.fromBytes(
      int versionNo, int indexFileSize, ByteDataReader reader) {
    var startingBytes = indexFileSize - reader.remainingLength;

    var ctimeSeconds = reader.readUint32();
    var ctimeNanoSeconds = reader.readUint32();

    cTime = DateTime.fromMicrosecondsSinceEpoch(0, isUtc: true);
    cTime = cTime.add(Duration(seconds: ctimeSeconds));
    cTime = cTime.add(Duration(microseconds: ctimeNanoSeconds ~/ 1000));

    var mtimeSeconds = reader.readUint32();
    var mtimeNanoSeconds = reader.readUint32();

    mTime = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    mTime = mTime.add(Duration(seconds: mtimeSeconds));
    mTime = mTime.add(Duration(microseconds: mtimeNanoSeconds ~/ 1000));

    dev = reader.readUint32();
    ino = reader.readUint32();

    // Mode
    mode = GitFileMode(reader.readUint32());

    uid = reader.readUint32();
    gid = reader.readUint32();

    fileSize = reader.readUint32();
    hash = GitHash.fromBytes(reader.read(20));

    var flags = reader.readUint16();
    stage = GitFileStage((flags >> 12) & 0x3);

    const hasExtendedFlag = 0x4000;
    if (flags & hasExtendedFlag != 0) {
      if (versionNo <= 2) {
        throw Exception('Index version 2 must not have an extended flag');
      }
      reader.readUint16(); // extra Flags
      // What to do with these extraFlags?
    }

    // Read name
    switch (versionNo) {
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
    if (versionNo == 4) {
      return;
    }
    var endingBytes = indexFileSize - reader.remainingLength;
    var entrySize = endingBytes - startingBytes;
    var padLength = 8 - (entrySize % 8);
    reader.read(padLength);
  }

  Uint8List serialize() {
    var writer = ByteDataWriter(endian: Endian.big);

    cTime = cTime.toUtc();
    writer.writeUint32(cTime.millisecondsSinceEpoch ~/ 1000);
    writer.writeUint32((cTime.millisecond * 1000 + cTime.microsecond) * 1000);

    mTime = mTime.toUtc();
    writer.writeUint32(mTime.millisecondsSinceEpoch ~/ 1000);
    writer.writeUint32((mTime.millisecond * 1000 + mTime.microsecond) * 1000);

    writer.writeUint32(dev);
    writer.writeUint32(ino);

    writer.writeUint32(mode.val);

    writer.writeUint32(uid);
    writer.writeUint32(gid);
    writer.writeUint32(fileSize);

    writer.write(hash.bytes);

    var flags = (stage.val & 0x3) << 12;
    const nameMask = 0xfff;

    if (path.length < nameMask) {
      flags |= path.length;
    } else {
      flags |= nameMask;
    }

    writer.writeUint16(flags);
    writer.write(ascii.encode(path));

    // Add padding
    const entryHeaderLength = 62;
    var wrote = entryHeaderLength + path.length;
    var padLen = 8 - wrote % 8;
    writer.write(Uint8List(padLen));

    return writer.toBytes();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitIndexEntry &&
          runtimeType == other.runtimeType &&
          cTime == other.cTime &&
          mTime == other.mTime &&
          dev == other.dev &&
          ino == other.ino &&
          uid == other.uid &&
          gid == other.gid &&
          fileSize == other.fileSize &&
          hash == other.hash &&
          stage == other.stage &&
          path == other.path;

  @override
  int get hashCode => path.hashCode ^ hash.hashCode;

  @override
  String toString() {
    return 'GitIndexEntry{cTime: $cTime, mTime: $mTime, dev: $dev, ino: $ino, uid: $uid, gid: $gid, fileSize: $fileSize, hash: $hash, stage: $stage, path: $path}';
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

class GitFileMode extends Equatable {
  final int val;

  const GitFileMode(this.val);

  static final Empty = GitFileMode(0);
  static final Dir = GitFileMode(int.parse('40000', radix: 8));
  static final Regular = GitFileMode(int.parse('100644', radix: 8));
  static final Deprecated = GitFileMode(int.parse('100664', radix: 8));
  static final Executable = GitFileMode(int.parse('100755', radix: 8));
  static final Symlink = GitFileMode(int.parse('120000', radix: 8));
  static final Submodule = GitFileMode(int.parse('160000', radix: 8));

  @override
  List<Object> get props => [val];

  @override
  String toString() {
    return '$val';
  }

  // FIXME: Is this written in little endian in bytes?
}

class GitFileStage extends Equatable {
  final int val;

  const GitFileStage(this.val);

  static const Merged = GitFileStage(1);
  static const AncestorMode = GitFileStage(1);
  static const OurMode = GitFileStage(2);
  static const TheirMode = GitFileStage(3);

  @override
  List<Object> get props => [val];

  @override
  bool get stringify => true;
}
