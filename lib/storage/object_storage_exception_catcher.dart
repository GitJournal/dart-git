import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/utils/result.dart';
import 'interfaces.dart';

class ObjectStorageExceptionCatcher implements ObjectStorage {
  final ObjectStorage _;

  ObjectStorageExceptionCatcher({required ObjectStorage storage}) : _ = storage;

  @override
  Future<Result<GitObject>> read(GitHash hash) => catchAll(() => _.read(hash));

  @override
  Future<Result<GitHash>> writeObject(GitObject obj) => _.writeObject(obj);
}
