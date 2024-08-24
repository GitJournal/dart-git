import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:charcode/charcode.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:stdlibc/stdlibc.dart' as stdlibc;

import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/utils/ascii_helper.dart';
import 'package:dart_git/utils/bytes_data_reader.dart';
import 'package:dart_git/utils/file_mode.dart';
import 'package:dart_git/utils/uint8list.dart';

final _indexSignature = ascii.encode('DIRC');

class GitIndex {
  int versionNo = 0;
  var entries = <GitIndexEntry>[];

  List<TreeEntry> cache = []; // cached tree extension
  EndOfIndexEntry? endOfIndexEntry;

  GitIndex({required this.versionNo});

  GitIndex.decode(Uint8List bytes) {
    var reader = ByteDataReader(endian: Endian.big, copy: false);
    reader.add(bytes);

    // Read 12 byte header
    var sig = reader.read(4);
    if (sig.length != 4) {
      throw GitIndexCorruptedException('Invalid Signature length');
    }

    if (!_listEq(sig, _indexSignature)) {
      throw GitIndexCorruptedException('Invalid signature $sig');
    }

    versionNo = reader.readUint32();
    if (versionNo <= 1 || versionNo > 4) {
      throw Exception('GitIndexError: Version number not supported $versionNo');
    }

    // Read Index Entries
    var numEntries = reader.readUint32();
    for (var i = 0; i < numEntries; i++) {
      var lastEntry = i == 0 ? null : entries[i - 1];
      var entry =
          GitIndexEntry.fromBytes(versionNo, bytes.length, reader, lastEntry);
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

    var hashBytesBuilder = BytesBuilder(copy: false);
    hashBytesBuilder
      ..add(extensionHeader)
      ..add(reader.read(16));

    var expectedHash = GitHash.fromBytes(hashBytesBuilder.toBytes());
    var actualHash = GitHash.compute(bytes.sublistView(0, bytes.length - 20));
    if (expectedHash != actualHash) {
      throw GitIndexHashDifferentException(
        expected: expectedHash,
        actual: actualHash,
      );
    }
  }

  static final _treeHeader = ascii.encode('TREE');
  static final _reucHeader = ascii.encode('REUC');
  static final _eoicHeader = ascii.encode('EOIE');

  bool _parseExtension(List<int> header, ByteDataReader reader) {
    if (_listEq(header, _treeHeader)) {
      var length = reader.readUint32();
      var data = reader.read(length);
      _parseCacheTreeExtension(data);
      return true;
    }

    if (_listEq(header, _eoicHeader)) {
      var length = reader.readUint32();
      var data = reader.read(length);
      _parseEndOfIndexEntryExtension(data);
      return true;
    }

    if (_listEq(header, _reucHeader)) {
      var length = reader.readUint32();
      reader.read(length); // Ignoring the data for now
      return true;
    }

    return false;
  }

  void _parseCacheTreeExtension(Uint8List data) {
    var pos = 0;
    while (pos < data.length) {
      var pathEndPos = data.indexOf(0, pos);
      if (pathEndPos == -1) {
        throw GitIndexCorruptedException('Git Cache Index corrupted');
      }
      var path = data.sublistView(pos, pathEndPos);
      pos = pathEndPos + 1;

      var entryCountEndPos = data.indexOf($space, pos);
      if (entryCountEndPos == -1) {
        throw GitIndexCorruptedException('Git Cache Index corrupted');
      }
      var entryCount = data.sublistView(pos, entryCountEndPos);
      pos = entryCountEndPos + 1;
      assert(data[pos - 1] == $space);

      var numEntries = int.tryParse(ascii.decode(entryCount));
      if (numEntries == null) {
        // FIXME: Log this?
        continue;
      }
      if (numEntries == -1) {
        // FIXME: Should I be returning?
        return;
      }

      var numSubtreeEndPos = data.indexOf($newLine, pos);
      if (numSubtreeEndPos == -1) {
        throw GitIndexCorruptedException('Git Cache Index corrupted');
      }
      var numSubTreeData = data.sublistView(pos, numSubtreeEndPos);
      var numSubTrees = int.tryParse(ascii.decode(numSubTreeData));
      if (numSubTrees == null) {
        // FIXME: Log this?
        continue;
      }
      pos = numSubtreeEndPos + 1;
      assert(data[pos - 1] == $newLine);

      var hashBytes = data.sublistView(pos, pos + 20);
      pos += 20;

      var treeEntry = TreeEntry(
        path: utf8.decode(path),
        numEntries: numEntries,
        numSubTrees: numSubTrees,
        hash: GitHash.fromBytes(hashBytes),
      );
      cache.add(treeEntry);
    }
  }

  void _parseEndOfIndexEntryExtension(Uint8List data) {
    var reader = ByteDataReader(endian: Endian.big, copy: false);
    reader.add(data);

    if (endOfIndexEntry != null) {
      throw GitIndexCorruptedException(
          'Git Index "End of Index Extension" corrupted');
    }
    var offset = reader.readUint32();

    var bytes = reader.read(reader.remainingLength);
    if (bytes.length != 20) {
      throw GitIndexCorruptedException(
          'Git Index "End of Index Extension" hash corrupted');
    }
    var hash = GitHash.fromBytes(bytes);
    endOfIndexEntry = EndOfIndexEntry(offset, hash);
  }

  Uint8List serialize() {
    // Do we support this version of the index?
    if (versionNo != 2) {
      throw Exception(
          'Git Index version $versionNo cannot be serialized. Only version 2 is supported');
    }

    var writer = ByteDataWriter();

    // Header
    writer.write(_indexSignature);
    writer.writeUint32(versionNo);
    writer.writeUint32(entries.length);

    // Entries
    entries.sort((a, b) => a.path.compareTo(b.path));
    for (var e in entries) {
      writer.write(e.serialize());
    }

    // Footer
    var hash = GitHash.compute(writer.toBytes());
    writer.write(hash.bytes);

    return writer.toBytes();
  }

  static final _listEq = const ListEquality().equals;

  void updatePath(String path, GitHash hash, stdlibc.Stat stat) {
    var ei = entries.indexWhere((e) => e.path == path);
    if (ei == -1) {
      var entry = GitIndexEntry.fromFS(path, stat, hash);
      entries.add(entry);
      return;
    }

    // Existing file
    entries[ei] = GitIndexEntry.fromFS(path, stat, hash);
  }

  GitHash? removePath(String pathSpec) {
    var i = entries.indexWhere((e) => e.path == pathSpec);
    if (i == -1) {
      return null;
    }

    var indexEntry = entries.removeAt(i);
    return indexEntry.hash;
  }

  GitIndexEntry? entryWhere(bool Function(GitIndexEntry) filter) {
    var i = entries.indexWhere(filter);
    return i != -1 ? entries[i] : null;
  }
}

class GitIndexEntry {
  final DateTime cTime;
  final DateTime mTime;

  final int dev;
  final int ino;

  final GitFileMode mode;

  final int uid;
  final int gid;

  final int fileSize;
  final GitHash hash;

  final GitFileStage stage;

  final String path;

  final bool skipWorkTree;
  final bool intentToAdd;

  GitIndexEntry({
    required this.cTime,
    required this.mTime,
    required this.dev,
    required this.ino,
    required this.mode,
    required this.uid,
    required this.gid,
    required this.fileSize,
    required this.hash,
    this.stage = GitFileStage.Merged,
    required this.path,
    this.skipWorkTree = false,
    this.intentToAdd = false,
  });

  static GitIndexEntry fromFS(String path, stdlibc.Stat stat, GitHash hash) {
    assert(!path.startsWith('/'));

    return GitIndexEntry(
      cTime: stat.st_ctim,
      mTime: stat.st_mtim,
      dev: stat.st_dev,
      ino: stat.st_ino,
      mode: GitFileMode(stat.st_mode),
      uid: stat.st_uid,
      gid: stat.st_gid,
      fileSize: stat.st_size,
      hash: hash,
      stage: GitFileStage(0),
      path: path,
    );
  }

  static GitIndexEntry fromBytes(
    int versionNo,
    int indexFileSize,
    ByteDataReader reader,
    GitIndexEntry? lastEntry,
  ) {
    var startingBytes = indexFileSize - reader.remainingLength;

    var ctimeSeconds = reader.readUint32();
    var ctimeNanoSeconds = reader.readUint32();

    var cTime = DateTime.fromMicrosecondsSinceEpoch(0, isUtc: true);
    cTime = cTime.add(Duration(seconds: ctimeSeconds));
    cTime = cTime.add(Duration(microseconds: ctimeNanoSeconds ~/ 1000));

    var mtimeSeconds = reader.readUint32();
    var mtimeNanoSeconds = reader.readUint32();

    var mTime = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    mTime = mTime.add(Duration(seconds: mtimeSeconds));
    mTime = mTime.add(Duration(microseconds: mtimeNanoSeconds ~/ 1000));

    var dev = reader.readUint32();
    var ino = reader.readUint32();

    // Mode
    var mode = GitFileMode(reader.readUint32());

    var uid = reader.readUint32();
    var gid = reader.readUint32();

    var fileSize = reader.readUint32();
    var hash = GitHash.fromBytes(reader.read(20));

    var flags = reader.readUint16();
    var stage = GitFileStage((flags >> 12) & 0x3);

    var intentToAdd = false;
    var skipWorkTree = false;

    const hasExtendedFlag = 0x4000;
    if (flags & hasExtendedFlag != 0) {
      if (versionNo <= 2) {
        throw Exception('Index version 2 must not have an extended flag');
      }

      var extended = reader.readUint16(); // extra Flags

      const intentToAddMask = 1 << 13;
      const skipWorkTreeMask = 1 << 14;

      intentToAdd = (extended & intentToAddMask) > 0;
      skipWorkTree = (extended & skipWorkTreeMask) > 0;
    }

    // Read name
    var path = '';
    switch (versionNo) {
      case 2:
      case 3:
        const nameMask = 0xfff;
        var len = flags & nameMask;
        path = utf8.decode(reader.read(len));

      case 4:
        var l = reader.readVariableWidthInt();
        var base = '';
        if (lastEntry != null) {
          base = lastEntry.path.substring(0, lastEntry.path.length - l);
        }
        var name = reader.readUntil(0x00);
        path = base + utf8.decode(name);

      default:
        throw Exception('Index version not supported');
    }

    // Discard Padding
    if (versionNo != 4) {
      var endingBytes = indexFileSize - reader.remainingLength;
      var entrySize = endingBytes - startingBytes;
      var padLength = 8 - (entrySize % 8);
      reader.read(padLength);
    }

    return GitIndexEntry(
      cTime: cTime,
      mTime: mTime,
      dev: dev,
      ino: ino,
      mode: mode,
      uid: uid,
      gid: gid,
      fileSize: fileSize,
      hash: hash,
      stage: stage,
      path: path,
      skipWorkTree: skipWorkTree,
      intentToAdd: intentToAdd,
    );
  }

  Uint8List serialize() {
    if (intentToAdd || skipWorkTree) {
      throw Exception('Index Entry version not supported');
    }

    var writer = ByteDataWriter(endian: Endian.big);

    var w_cTime = cTime.toUtc();
    writer.writeUint32(w_cTime.millisecondsSinceEpoch ~/ 1000);
    writer
        .writeUint32((w_cTime.millisecond * 1000 + w_cTime.microsecond) * 1000);

    var w_mTime = mTime.toUtc();
    writer.writeUint32(w_mTime.millisecondsSinceEpoch ~/ 1000);
    writer
        .writeUint32((w_mTime.millisecond * 1000 + w_mTime.microsecond) * 1000);

    writer.writeUint32(dev);
    writer.writeUint32(ino);

    writer.writeUint32(mode.val);

    writer.writeUint32(uid);
    writer.writeUint32(gid);
    writer.writeUint32(fileSize);

    writer.write(hash.bytes);

    var flags = (stage.val & 0x3) << 12;
    const nameMask = 0xfff;

    var pathUtf8 = utf8.encode(path);
    flags |= pathUtf8.length < nameMask ? pathUtf8.length : nameMask;

    writer.writeUint16(flags);
    writer.write(pathUtf8); // This is a problem!

    // Add padding
    const entryHeaderLength = 62;
    var wrote = entryHeaderLength + pathUtf8.length;
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
          path == other.path &&
          intentToAdd == other.intentToAdd &&
          skipWorkTree == other.skipWorkTree;

  @override
  int get hashCode => Object.hashAll(serialize());

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

  const TreeEntry({
    required this.path,
    required this.numEntries,
    required this.numSubTrees,
    required this.hash,
  });

  @override
  List<Object?> get props => [path, numEntries, numSubTrees, hash];

  @override
  bool get stringify => true;
}

/// EndOfIndexEntry is the End of Index Entry (EOIE) is used to locate the end of
/// the variable length index entries and the beginning of the extensions. Code
/// can take advantage of this to quickly locate the index extensions without
/// having to parse through all of the index entries.
///
///  Because it must be able to be loaded before the variable length cache
///  entries and other index extensions, this extension must be written last.
class EndOfIndexEntry {
  final int offset;
  final GitHash hash;

  EndOfIndexEntry(this.offset, this.hash);
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
