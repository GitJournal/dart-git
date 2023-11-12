import 'package:path/path.dart' as p;

import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';

import 'package:dart_git/utils/utils.dart';
import 'interfaces.dart';

extension ObjectStorageExtension on ObjectStorage {
  GitTreeEntry refSpec(GitTree tree, String spec) {
    assert(!spec.startsWith(p.separator));

    if (spec.isEmpty) {
      return throw GitObjectWithRefSpecNotFound(spec);
    }

    var parts = splitPath(spec);
    var name = parts.item1;
    var remainingName = parts.item2;

    for (var leaf in tree.entries) {
      if (leaf.name == name) {
        if (remainingName.isEmpty) {
          return leaf;
        }

        var obj = read(leaf.hash);
        if (obj is GitTree) {
          return refSpec(obj, remainingName);
        }

        throw GitObjectWithRefSpecNotFound(spec);
      }
    }
    return throw GitObjectWithRefSpecNotFound(spec);
  }

  // TODO: What happens when we call readBlob on a commit?
  GitBlob readBlob(GitHash hash) => read(hash) as GitBlob;
  GitTree readTree(GitHash hash) => read(hash) as GitTree;
  GitCommit readCommit(GitHash hash) => read(hash) as GitCommit;
}
