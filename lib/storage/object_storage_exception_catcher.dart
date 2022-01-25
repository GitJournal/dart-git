import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/utils/result.dart';
import 'interfaces.dart';

class ObjectStorageExceptionCatcher implements ObjectStorage {
  final ObjectStorage _;

  ObjectStorageExceptionCatcher({required ObjectStorage storage}) : _ = storage;

  @override
  Result<GitObject> read(GitHash hash) => catchAllSync(() => _.read(hash));

  @override
  Result<GitHash> writeObject(GitObject obj) =>
      catchAllSync(() => _.writeObject(obj));

  @override
  Result<void> close() => catchAllSync(() => _.close());
}
