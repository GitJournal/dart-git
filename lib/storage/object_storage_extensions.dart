import 'package:path/path.dart' as p;

import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/storage/object_storage.dart';
import 'package:dart_git/utils/result.dart';
import 'package:dart_git/utils/utils.dart';

extension ObjectStorageExtension on ObjectStorage {
  Future<Result<GitTreeEntry>> refSpec(GitTree tree, String spec) async {
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

        var result = await read(leaf.hash);
        if (result.isFailure) {
          return fail(result);
        }
        var obj = result.getOrThrow();

        return obj is GitTree
            ? await refSpec(obj, remainingName)
            : Result.fail(GitObjectWithRefSpecNotFound(spec));
      }
    }
    return Result.fail(GitObjectWithRefSpecNotFound(spec));
  }
}
