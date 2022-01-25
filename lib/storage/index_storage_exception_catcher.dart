import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/utils/result.dart';
import 'interfaces.dart';

class IndexStorageExceptionCatcher implements IndexStorage {
  final IndexStorage _;

  IndexStorageExceptionCatcher({required IndexStorage storage}) : _ = storage;

  @override
  Result<GitIndex> readIndex() => catchAllSync(() => _.readIndex());

  @override
  Result<void> writeIndex(GitIndex index) =>
      catchAllSync(() => _.writeIndex(index));

  @override
  Result<void> close() => catchAllSync(() => _.close());
}
