import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:dart_git/ascii_helper.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/utils/file_mode.dart';

class GitTreeEntry extends Equatable {
  final GitFileMode mode;
  final String name;
  final GitHash hash;

  GitTreeEntry({required this.mode, required this.name, required this.hash});

  @override
  List<Object> get props => [mode, name, hash];

  @override
  bool get stringify => true;
}

class GitTree extends GitObject {
  static const fmt = ObjectTypes.TREE_STR;
  static final _fmt = ascii.encode(fmt);

  GitHash? _hash;
  List<GitTreeEntry> entries = [];

  GitTree.empty() : _hash = null;

  GitTree(Uint8List raw, this._hash) {
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
  Uint8List serializeData() {
    final bytesBuilder = BytesBuilder(copy: false);

    for (var e in entries) {
      bytesBuilder
        ..add(ascii.encode(e.mode.toString()))
        ..addByte(asciiHelper.space)
        ..add(utf8.encode(e.name))
        ..addByte(0x00)
        ..add(e.hash.bytes);
    }

    return bytesBuilder.toBytes();
  }

  @override
  Uint8List format() => _fmt;

  @override
  String formatStr() => fmt;

  @override
  GitHash get hash {
    _hash ??= GitHash.compute(serialize());
    return _hash!;
  }

  void debugPrint() {
    for (var e in entries) {
      print('${e.mode} ${e.name} ${e.hash}');
    }
  }
}
