import 'dart:collection';

import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/storage/interfaces.dart';
import 'package:dart_git/utils/git_hash_set.dart';

// FIXME: How to deal with missing objects?

Iterable<GitCommit> commitIteratorBFS({
  required ObjectStorage objStorage,
  required GitHash from,
}) sync* {
  var queue = Queue<GitHash>.from([from]);
  var seen = GitHashSet();

  while (queue.isNotEmpty) {
    var hash = queue.removeFirst();
    if (seen.contains(hash)) {
      continue;
    }
    seen.add(hash);

    var commit = objStorage.readCommit(hash);
    queue.addAll(commit.parents);
    yield commit;
  }
}

typedef CommitFilter = bool Function(GitCommit commit);
typedef CommitHashFilter = bool Function(GitHash commitHash);

final _allCommitsValidFilter = (GitCommit _) => true;
final _allCommitsNotValidFilter = (GitCommit _) => false;
final _doNotSkip = (GitHash _) => false;

Iterable<GitCommit> commitIteratorBFSFiltered({
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
  var seen = GitHashSet();

  while (queue.isNotEmpty) {
    var hash = queue.removeFirst();
    if (seen.contains(hash) || skipCommitHash(hash)) {
      continue;
    }
    seen.add(hash);

    var commit = objStorage.readCommit(hash);
    if (!isLimit(commit)) {
      queue.addAll(commit.parents);
    }
    if (isValid(commit)) {
      yield commit;
    }
  }
}

Iterable<GitCommit> commitPreOrderIterator({
  required ObjectStorage objStorage,
  required GitHash from,
}) sync* {
  var stack = List<GitHash>.from([from]);
  var seen = GitHashSet();

  while (stack.isNotEmpty) {
    var hash = stack.removeLast();
    if (seen.contains(hash)) {
      continue;
    }
    seen.add(hash);

    var commit = objStorage.readCommit(hash);
    stack.addAll(commit.parents.reversed);
    yield commit;
  }
}
