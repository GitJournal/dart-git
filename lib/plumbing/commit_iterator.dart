import 'dart:collection';

import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/storage/interfaces.dart';
import 'package:dart_git/utils/result.dart';

// FIXME: How to deal with missing objects?

Stream<Result<GitCommit>> commitIteratorBFS({
  required ObjectStorage objStorage,
  required GitCommit from,
}) async* {
  var queue = Queue<GitHash>.from([from.hash]);
  var seen = <GitHash>{};

  while (queue.isNotEmpty) {
    var hash = queue.removeFirst();
    if (seen.contains(hash)) {
      continue;
    }
    seen.add(hash);

    var result = await objStorage.readCommit(hash);
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
final _allCommitsValidFilter = (GitCommit _) => true;
final _allCommitsNotValidFilter = (GitCommit _) => false;

Stream<Result<GitCommit>> commitIteratorBFSFiltered({
  required ObjectStorage objStorage,
  required GitCommit from,
  CommitFilter? isValid,
  CommitFilter? isLimit,
}) async* {
  isValid ??= _allCommitsValidFilter;
  isLimit ??= _allCommitsNotValidFilter;

  var queue = Queue<GitHash>.from([from.hash]);
  var seen = <GitHash>{};

  while (queue.isNotEmpty) {
    var hash = queue.removeFirst();
    if (seen.contains(hash)) {
      continue;
    }
    seen.add(hash);

    var result = await objStorage.readCommit(hash);
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

Stream<Result<GitCommit>> commitPreOrderIterator({
  required ObjectStorage objStorage,
  required GitCommit from,
}) async* {
  var stack = List<GitHash>.from([from.hash]);
  var seen = <GitHash>{};

  while (stack.isNotEmpty) {
    var hash = stack.removeLast();
    if (seen.contains(hash)) {
      continue;
    }
    seen.add(hash);

    var result = await objStorage.readCommit(hash);
    if (result.isFailure) {
      yield fail(result);
      continue;
    }
    var commit = result.getOrThrow();

    stack.addAll(commit.parents.reversed);
    yield Result(commit);
  }
}
