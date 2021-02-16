import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'package:dart_git/ascii_helper.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/object.dart';

class GitTreeEntry extends Equatable {
  final GitFileMode mode;
  final String name;
  final GitHash hash;

  GitTreeEntry({@required this.mode, @required this.name, @required this.hash});

  @override
  List<Object> get props => [mode, name, hash];

  @override
  bool get stringify => true;
}

class GitTree extends GitObject {
  static const String fmt = ObjectTypes.TREE_STR;
  static final List<int> _fmt = ascii.encode(fmt);

  GitHash _hash;
  List<GitTreeEntry> entries = [];

  GitTree.empty() : _hash = null;

  GitTree(List<int> raw, this._hash) {
    var start = 0;
    while (start < raw.length) {
      var x = raw.indexOf(asciiHelper.space, start);
      assert(x - start == 5 || x - start == 6);

      var mode = raw.sublist(start, x);
      var y = raw.indexOf(0, x);
      var name = raw.sublist(x + 1, y);
      var hashBytes = raw.sublist(y + 1, y + 21);

      var entry = GitTreeEntry(
        mode: GitFileMode.parse(ascii.decode(mode)),
        name: utf8.decode(name),
        hash: GitHash.fromBytes(hashBytes),
      );

      entries.add(entry);

      start = y + 21;
    }
  }

  @override
  List<int> serializeData() {
    var data = <int>[];

    for (var e in entries) {
      assert(e.hash != null);
      assert(e.name != null && e.name.isNotEmpty);
      assert(e.mode != null);

      data.addAll(ascii.encode(e.mode.toString()));
      data.add(asciiHelper.space);
      data.addAll(utf8.encode(e.name));
      data.add(0x00);
      data.addAll(e.hash.bytes);
    }

    return data;
  }

  @override
  List<int> format() => _fmt;

  @override
  String formatStr() => fmt;

  @override
  GitHash get hash {
    _hash ??= GitHash.compute(serialize());
    return _hash;
  }

  void debugPrint() {
    for (var e in entries) {
      print('${e.mode} ${e.name} ${e.hash}');
    }
  }
}
