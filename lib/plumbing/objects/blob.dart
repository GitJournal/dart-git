import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';

class GitBlob extends GitObject {
  static const fmt = ObjectTypes.BLOB_STR;
  static final _fmt = ascii.encode(fmt);

  final Uint8List blobData;

  @override
  late final GitHash hash;

  GitBlob(this.blobData, GitHash? hash) {
    this.hash = hash ?? GitHash.computeForObject(this);
  }

  @override
  Uint8List serializeData() => blobData;

  @override
  Uint8List format() => _fmt;

  @override
  String formatStr() => fmt;
}
