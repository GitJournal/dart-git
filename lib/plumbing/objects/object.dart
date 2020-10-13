import 'dart:convert';

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
}

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
