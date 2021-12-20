import 'package:stash_memory/stash_memory.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/utils/result.dart';
import 'interfaces.dart';

class ObjectStorageCache implements ObjectStorage {
  final ObjectStorage _;
  final cache = newMemoryCache(maxEntries: 10000);

  // The eviction should be based on time and usage

  ObjectStorageCache({required ObjectStorage storage}) : _ = storage;

  @override
  Future<Result<GitObject>> read(GitHash hash) async {
    var hashStr = hash.toString();
    var val = await cache[hashStr] as GitObject?;
    if (val != null) {
      return Result(val);
    }

    var objR = await _.read(hash);
    if (objR.isSuccess) {
      var obj = objR.getOrThrow();
      if (obj is GitTree) {
        await cache.put(hashStr, obj);
      }
    }
    return objR;
  }

  @override
  Future<Result<GitHash>> writeObject(GitObject obj) => _.writeObject(obj);
}
