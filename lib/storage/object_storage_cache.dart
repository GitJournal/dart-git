import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/plumbing/objects/tree.dart';

import 'interfaces.dart';

class ObjectStorageCache implements ObjectStorage {
  final ObjectStorage _;
  // final cache = newMemoryCache(maxEntries: 10000);
  // FIXME: This cache should have a fixed size!
  final cache = <GitHash, GitObject>{};

  // The eviction should be based on time and usage

  ObjectStorageCache({required ObjectStorage storage}) : _ = storage;

  @override
  GitObject? read(GitHash hash) {
    var val = cache[hash];
    if (val != null) {
      return val;
    }

    var obj = _.read(hash);
    if (obj is GitTree) {
      cache[hash] = obj;
    }
    return obj;
  }

  @override
  GitHash writeObject(GitObject obj) => _.writeObject(obj);

  @override
  void close() => _.close();
}
