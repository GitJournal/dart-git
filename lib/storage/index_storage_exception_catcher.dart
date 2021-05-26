import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/storage/index_storage.dart';
import 'package:dart_git/utils/result.dart';

class IndexStorageExceptionCatcher implements IndexStorage {
  final IndexStorage _;

  IndexStorageExceptionCatcher({required IndexStorage storage}) : _ = storage;

  @override
  Future<Result<GitIndex>> readIndex() => catchAll(() => _.readIndex());

  @override
  Future<Result<void>> writeIndex(GitIndex index) =>
      catchAll(() => _.writeIndex(index));
}
