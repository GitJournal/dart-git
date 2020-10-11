import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'package:dart_git/ascii_helper.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';

class GitTreeLeaf extends Equatable {
  final String mode;
  final String path;
  final GitHash hash;

  GitTreeLeaf({@required this.mode, @required this.path, @required this.hash});

  @override
  List<Object> get props => [mode, path, hash];

  @override
  bool get stringify => true;
}

class GitTree extends GitObject {
  static const String fmt = 'tree';
  static final List<int> _fmt = ascii.encode(fmt);

  final GitHash _hash;
  List<GitTreeLeaf> leaves = [];

  GitTree(List<int> raw, this._hash) {
    var start = 0;
    while (start < raw.length) {
      var x = raw.indexOf(asciiHelper.space, start);
      assert(x - start == 5 || x - start == 6);

      var mode = raw.sublist(start, x);
      var y = raw.indexOf(0, x);
      var path = raw.sublist(x + 1, y);
      var hashBytes = raw.sublist(y + 1, y + 21);

      var leaf = GitTreeLeaf(
        mode: ascii.decode(mode),
        path: utf8.decode(path),
        hash: GitHash.fromBytes(hashBytes),
      );

      leaves.add(leaf);

      start = y + 21;
    }
  }

  @override
  List<int> serializeData() {
    var data = <int>[];

    for (var leaf in leaves) {
      data.addAll(ascii.encode(leaf.mode));
      data.add(asciiHelper.space);
      data.addAll(utf8.encode(leaf.path));
      data.add(0x00);
      data.addAll(leaf.hash.bytes);
    }

    return data;
  }

  @override
  List<int> format() => _fmt;

  @override
  GitHash hash() => _hash ?? GitHash.compute(serialize());
}
