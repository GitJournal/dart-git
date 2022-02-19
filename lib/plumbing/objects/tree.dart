import 'dart:convert';
import 'dart:typed_data';

import 'package:charcode/charcode.dart';
import 'package:equatable/equatable.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/utils/file_mode.dart';
import 'package:dart_git/utils/uint8list.dart';

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

  @override
  late final GitHash hash;
  late final IList<GitTreeEntry> entries;

  GitTree._(this.hash, this.entries);

  static GitTree create([Iterable<GitTreeEntry>? entries]) {
    var t = GitTree._(GitHash.zero(), IList(entries));
    var hash = GitHash.computeForObject(t);
    return GitTree._(hash, t.entries);
  }

  GitTree(Uint8List raw, this.hash) {
    var start = 0;
    var entries = <GitTreeEntry>[];
    while (start < raw.length) {
      var x = raw.indexOf($space, start);
      assert(x - start == 5 || x - start == 6);

      var mode = raw.sublistView(start, x);
      var y = raw.indexOf(0, x);
      var name = raw.sublistView(x + 1, y);
      var hashBytes = raw.sublistView(y + 1, y + 21);

      var entry = GitTreeEntry(
        mode: GitFileMode.parse(ascii.decode(mode)),
        name: utf8.decode(name),
        hash: GitHash.fromBytes(hashBytes),
      );

      entries.add(entry);

      start = y + 21;
    }

    this.entries = IList(entries);
  }

  @override
  Uint8List serializeData() {
    final bytesBuilder = BytesBuilder(copy: false);

    for (var e in entries) {
      bytesBuilder
        ..add(ascii.encode(e.mode.toString()))
        ..addByte($space)
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

  void debugPrint() {
    for (var e in entries) {
      // ignore: avoid_print
      print('${e.mode} ${e.name} ${e.hash}');
    }
  }
}
