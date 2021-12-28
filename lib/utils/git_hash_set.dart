import 'dart:typed_data';

import 'package:dart_git/plumbing/git_hash.dart';

class GitHashSet {
  late final Uint16List byteTables;
  final _set = <GitHash>{};

  GitHashSet() {
    byteTables = Uint16List(256 * 20);
  }

  GitHashSet.from(Iterable<GitHash>? iter) {
    byteTables = Uint16List(256 * 20);

    if (iter == null) return;
    for (var hash in iter) {
      add(hash);
    }
  }

  void add(GitHash hash) {
    var _ = _set.add(hash);
    for (var i = 0; i < 20; i++) {
      var byte = hash.bytes[i];
      byteTables[(i * 256) + byte] += 1;

      if (byteTables[(i * 256) + byte] > _int16Max) {
        throw Exception('GitHashSet Full');
      }
    }
  }

  bool contains(GitHash hash) {
    if (!_bloomContains(hash)) return false;
    return _set.contains(hash);
  }

  /// Can give a false positive
  bool _bloomContains(GitHash hash) {
    for (var i = 0; i < 20; i++) {
      var byte = hash.bytes[i];
      if (byteTables[(i * 256) + byte] == 0) {
        return false;
      }
    }
    return true;
  }

  int get length => _set.length;
}

var _int16Max = 0xffff;
