import 'dart:convert';

import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';

class GitBlob extends GitObject {
  static const String fmt = ObjectTypes.BLOB_STR;
  static final List<int> _fmt = ascii.encode(fmt);

  final List<int> blobData;
  final GitHash _hash;

  GitBlob(this.blobData, this._hash);

  @override
  List<int> serializeData() => blobData;

  @override
  List<int> format() => _fmt;

  @override
  String formatStr() => fmt;

  @override
  GitHash hash() => _hash ?? GitHash.compute(serialize());
}
