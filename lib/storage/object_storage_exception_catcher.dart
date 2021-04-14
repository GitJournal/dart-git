import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/storage/object_storage.dart';

class ObjectStorageExceptionCatcher implements ObjectStorage {
  final ObjectStorage _;

  ObjectStorageExceptionCatcher({required ObjectStorage storage}) : _ = storage;

  @override
  Future<GitObjectResult> read(GitHash hash) async =>
      await GitObjectResult.catchAll(() => _.read(hash));

  @override
  Future<GitBlobResult> readBlob(GitHash hash) async =>
      await GitBlobResult.catchAll(() => _.readBlob(hash));

  @override
  Future<GitCommitResult> readCommit(GitHash hash) async =>
      await GitCommitResult.catchAll(() => _.readCommit(hash));

  @override
  Future<GitTreeResult> readTree(GitHash hash) async =>
      await GitTreeResult.catchAll(() => _.readTree(hash));

  @override
  Future<GitObjectResult> readObjectFromPath(String filePath) =>
      _.readObjectFromPath(filePath);

  // FIXME: Catch exceptions over here!
  @override
  Future<GitHash> writeObject(GitObject obj) => _.writeObject(obj);

  @override
  Future<GitObjectResult> refSpec(GitTree tree, String spec) async =>
      await GitObjectResult.catchAll(() => _.refSpec(tree, spec));
}
