import 'dart:convert';

import 'package:collection/collection.dart';

import 'package:dart_git/ascii_helper.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';

abstract class GitObject {
  List<int> serialize() {
    var data = serializeData();
    var result = [
      ...format(),
      asciiHelper.space,
      ...ascii.encode(data.length.toString()),
      0x0,
      ...data,
    ];

    //assert(GitHash.compute(result) == hash());
    return result;
  }

  List<int> serializeData();
  List<int> format();
  String formatStr();

  GitHash hash();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitObject && _listEq(serialize(), other.serialize());
}

Function _listEq = const ListEquality().equals;

GitObject createObject(String fmt, List<int> rawData, [String filePath]) {
  if (fmt == GitBlob.fmt) {
    return GitBlob(rawData, null);
  } else if (fmt == GitCommit.fmt) {
    return GitCommit(rawData, null);
  } else if (fmt == GitTree.fmt) {
    return GitTree(rawData, null);
  } else {
    throw Exception('Unknown type $fmt for object $filePath');
  }
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
        throw Exception('unsupported pack type ${type}');
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
        throw Exception('unsupported pack type ${type}');
    }
  }
}
