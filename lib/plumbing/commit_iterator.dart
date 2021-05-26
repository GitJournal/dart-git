import 'dart:collection';

import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/storage/object_storage.dart';

// FIXME: How to deal with missing objects?

Stream<GitCommit> commitIteratorBFS({
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
    var commit = result.get();

    queue.addAll(commit.parents);
    yield commit;
  }
}

typedef CommitFilter = bool Function(GitCommit commit);
final _allCommitsValidFilter = (GitCommit _) => true;
final _allCommitsNotValidFilter = (GitCommit _) => false;

Stream<GitCommit> commitIteratorBFSFiltered({
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
    var commit = result.get();

    if (!isLimit(commit)) {
      queue.addAll(commit.parents);
    }
    if (isValid(commit)) {
      yield commit;
    }
  }
}

Stream<GitCommit> commitPreOrderIterator({
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
    var commit = result.get();

    stack.addAll(commit.parents.reversed);
    yield commit;
  }
}
