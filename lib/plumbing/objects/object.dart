import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'package:dart_git/ascii_helper.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/storage/object_storage.dart';

abstract class GitObject {
  Uint8List serialize() {
    var data = serializeData();

    final bytesBuilder = BytesBuilder(copy: false);
    bytesBuilder
      ..add(format())
      ..addByte(asciiHelper.space)
      ..add(ascii.encode(data.length.toString()))
      ..addByte(0x0)
      ..add(data);

    //assert(GitHash.compute(result) == hash());
    return bytesBuilder.toBytes();
  }

  Uint8List serializeData();
  Uint8List format();
  String formatStr();

  GitHash get hash;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitObject && _listEq(serialize(), other.serialize());

  // @override
  // int get hashCode => serialize().hashCode;
}

Function _listEq = const ListEquality().equals;

GitObjectResult createObject(String fmt, Uint8List rawData,
    [String? filePath]) {
  GitObject obj;

  if (fmt == GitBlob.fmt) {
    obj = GitBlob(rawData, null);
  } else if (fmt == GitCommit.fmt) {
    // FIXME: Handle the case of this being null
    obj = GitCommit.parse(rawData, null)!;
  } else if (fmt == GitTree.fmt) {
    obj = GitTree(rawData, null);
  } else {
    return GitObjectResult.fail(GitObjectInvalidType(fmt));
  }

  return GitObjectResult(obj);
}

abstract class ObjectTypes {
  static const String BLOB_STR = 'blob';
  static const String TREE_STR = 'tree';
  static const String COMMIT_STR = 'commit';
  static const String TAG_STR = 'tag';
  static const String OFS_DELTA_STR = 'ofs_delta';
  static const String REF_DELTA_STR = 'ref_delta';

  static const int COMMIT = 1;
  static const int TREE = 2;
  static const int BLOB = 3;
  static const int TAG = 4;
  static const int OFS_DELTA = 6;
  static const int REF_DELTA = 7;

  static String getTypeString(int type) {
    switch (type) {
      case COMMIT:
        return COMMIT_STR;
      case TREE:
        return TREE_STR;
      case BLOB:
        return BLOB_STR;
      case TAG:
        return TAG_STR;
      case OFS_DELTA:
        return OFS_DELTA_STR;
      case REF_DELTA:
        return REF_DELTA_STR;
      default:
        throw Exception('unsupported pack type $type');
    }
  }

  static int getType(String type) {
    switch (type) {
      case COMMIT_STR:
        return COMMIT;
      case TREE_STR:
        return TREE;
      case BLOB_STR:
        return BLOB;
      case TAG_STR:
        return TAG;
      case OFS_DELTA_STR:
        return OFS_DELTA;
      case REF_DELTA_STR:
        return REF_DELTA;
      default:
        throw Exception('unsupported pack type $type');
    }
  }
}
