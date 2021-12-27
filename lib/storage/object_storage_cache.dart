import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/utils/result.dart';
import 'interfaces.dart';

class ObjectStorageCache implements ObjectStorage {
  final ObjectStorage _;
  // final cache = newMemoryCache(maxEntries: 10000);
  // FIXME: This cache should have a fixed size!
  final cache = <GitHash, GitObject>{};

  // The eviction should be based on time and usage

  ObjectStorageCache({required ObjectStorage storage}) : _ = storage;

  @override
  Result<GitObject> read(GitHash hash) {
    var val = cache[hash];
    if (val != null) {
      return Result(val);
    }

    var objR = _.read(hash);
    if (objR.isSuccess) {
      var obj = objR.getOrThrow();
      if (obj is GitTree) {
        cache[hash] = obj;
      }
    }
    return objR;
  }

  @override
  Result<GitHash> writeObject(GitObject obj) => _.writeObject(obj);
}
