import 'dart:collection';

import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/storage/interfaces.dart';
import 'package:dart_git/utils/result.dart';

// FIXME: How to deal with missing objects?

Iterable<Result<GitCommit>> commitIteratorBFS({
  required ObjectStorage objStorage,
  required GitHash from,
}) sync* {
  var queue = Queue<GitHash>.from([from]);
  var seen = <GitHash>{};

  while (queue.isNotEmpty) {
    var hash = queue.removeFirst();
    if (seen.contains(hash)) {
      continue;
    }
    var _ = seen.add(hash);

    var result = objStorage.readCommit(hash);
    if (result.isFailure) {
      yield fail(result);
      continue;
    }
    var commit = result.getOrThrow();

    queue.addAll(commit.parents);
    yield Result(commit);
  }
}

typedef CommitFilter = bool Function(GitCommit commit);
typedef CommitHashFilter = bool Function(GitHash commitHash);

final _allCommitsValidFilter = (GitCommit _) => true;
final _allCommitsNotValidFilter = (GitCommit _) => false;
final _doNotSkip = (GitHash _) => false;

Iterable<Result<GitCommit>> commitIteratorBFSFiltered({
  required ObjectStorage objStorage,
  required GitHash from,
  CommitFilter? isValid,
  CommitFilter? isLimit,
  CommitHashFilter? skipCommitHash,
}) sync* {
  isValid ??= _allCommitsValidFilter;
  isLimit ??= _allCommitsNotValidFilter;
  skipCommitHash ??= _doNotSkip;

  var queue = Queue<GitHash>.from([from]);
  var seen = <GitHash>{};

  while (queue.isNotEmpty) {
    var hash = queue.removeFirst();
    if (seen.contains(hash) || skipCommitHash(hash)) {
      continue;
    }
    var _ = seen.add(hash);

    var result = objStorage.readCommit(hash);
    if (result.isFailure) {
      yield fail(result);
      continue;
    }
    var commit = result.getOrThrow();

    if (!isLimit(commit)) {
      queue.addAll(commit.parents);
    }
    if (isValid(commit)) {
      yield Result(commit);
    }
  }
}

Iterable<Result<GitCommit>> commitPreOrderIterator({
  required ObjectStorage objStorage,
  required GitHash from,
}) sync* {
  var stack = List<GitHash>.from([from]);
  var seen = <GitHash>{};

  while (stack.isNotEmpty) {
    var hash = stack.removeLast();
    if (seen.contains(hash)) {
      continue;
    }
    var _ = seen.add(hash);

    var result = objStorage.readCommit(hash);
    if (result.isFailure) {
      yield fail(result);
      continue;
    }
    var commit = result.getOrThrow();

    stack.addAll(commit.parents.reversed);
    yield Result(commit);
  }
}
