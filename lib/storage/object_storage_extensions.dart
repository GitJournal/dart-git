import 'package:path/path.dart' as p;

import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/utils/result.dart';
import 'package:dart_git/utils/utils.dart';
import 'interfaces.dart';

extension ObjectStorageExtension on ObjectStorage {
  Result<GitTreeEntry> refSpec(GitTree tree, String spec) {
    assert(!spec.startsWith(p.separator));

    if (spec.isEmpty) {
      return Result.fail(GitObjectWithRefSpecNotFound(spec));
    }

    var parts = splitPath(spec);
    var name = parts.item1;
    var remainingName = parts.item2;

    for (var leaf in tree.entries) {
      if (leaf.name == name) {
        if (remainingName.isEmpty) {
          return Result(leaf);
        }

        var result = read(leaf.hash);
        if (result.isFailure) {
          return fail(result);
        }
        var obj = result.getOrThrow();

        return obj is GitTree
            ? refSpec(obj, remainingName)
            : Result.fail(GitObjectWithRefSpecNotFound(spec));
      }
    }
    return Result.fail(GitObjectWithRefSpecNotFound(spec));
  }

  // TODO: What happens when we call readBlob on a commit?
  Result<GitBlob> readBlob(GitHash hash) => downcast(read(hash));
  Result<GitTree> readTree(GitHash hash) => downcast(read(hash));
  Result<GitCommit> readCommit(GitHash hash) => downcast(read(hash));
}
