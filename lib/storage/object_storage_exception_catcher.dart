import 'package:dart_git/dart_git.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/storage/object_storage.dart';
import 'package:dart_git/utils/result.dart';

class ObjectStorageExceptionCatcher implements ObjectStorage {
  final ObjectStorage _;

  ObjectStorageExceptionCatcher({required ObjectStorage storage}) : _ = storage;

  @override
  Future<Result<GitObject>> read(GitHash hash) => catchAll(() => _.read(hash));

  @override
  Future<Result<GitBlob>> readBlob(GitHash hash) =>
      catchAll(() => _.readBlob(hash));

  @override
  Future<Result<GitCommit>> readCommit(GitHash hash) =>
      catchAll(() => _.readCommit(hash));

  @override
  Future<Result<GitTree>> readTree(GitHash hash) =>
      catchAll(() => _.readTree(hash));

  @override
  Future<Result<GitObject>> readObjectFromPath(String filePath) =>
      _.readObjectFromPath(filePath);

  // FIXME: Catch exceptions over here!
  @override
  Future<GitHash> writeObject(GitObject obj) => _.writeObject(obj);

  @override
  Future<Result<GitObject>> refSpec(GitTree tree, String spec) =>
      catchAll(() => _.refSpec(tree, spec));
}
