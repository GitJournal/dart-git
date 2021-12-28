import 'package:dart_git/dart_git.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/commit_iterator.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/utils/git_hash_set.dart';

extension MergeBase on GitRepository {
  /// mergeBase mimics the behavior of `git merge-base actual other`, returning the
  /// best common ancestor between the actual and the passed one.
  /// The best common ancestors can not be reached from other common ancestors.
  Result<List<GitCommit>> mergeBase(GitCommit a, GitCommit b) {
    var clist = [a, b];
    clist.sort(_commitDateDec);

    var newer = clist[0];
    var older = clist[1];

    var newerHistoryR = allAncestors(newer, shouldNotContain: older);
    if (newerHistoryR.isFailure) {
      if (newerHistoryR.error is GitShouldNotContainFound) {
        return Result([older]);
      }
      return fail(newerHistoryR);
    }
    var newerHistory = newerHistoryR.getOrThrow();

    var inNewerHistory = (GitCommit c) => newerHistory.contains(c.hash);

    var results = <GitCommit>[];
    var iter = commitIteratorBFSFiltered(
      objStorage: objStorage,
      from: older.hash,
      isValid: inNewerHistory,
      isLimit: inNewerHistory,
    );
    for (var r in iter) {
      if (r.isFailure) {
        return fail(r);
      }
      var commit = r.getOrThrow();
      results.add(commit);
    }

    return independents(results);
  }

  Result<Set<GitHash>> allAncestors(
    GitCommit start, {
    required GitCommit shouldNotContain,
  }) {
    if (start.hash == shouldNotContain.hash) {
      var ex = GitShouldNotContainFound();
      return Result.fail(ex);
    }

    var all = <GitHash>{};
    var iter = commitIteratorBFS(objStorage: objStorage, from: start.hash);
    for (var commitR in iter) {
      if (commitR.isFailure) {
        return fail(commitR);
      }
      var commit = commitR.getOrThrow();
      if (commit.hash == shouldNotContain.hash) {
        var ex = GitShouldNotContainFound();
        return Result.fail(ex);
      }

      var _ = all.add(commit.hash);
    }

    return Result(all);
  }

  /// isAncestor returns true if the actual commit is ancestor of the passed one.
  /// It returns an error if the history is not transversable
  /// It mimics the behavior of `git merge --is-ancestor actual other`
  Result<bool> isAncestor(GitCommit ancestor, GitCommit child) {
    var iter = commitPreOrderIterator(objStorage: objStorage, from: child.hash);
    for (var commitR in iter) {
      if (commitR.isFailure) {
        return fail(commitR);
      }
      var commit = commitR.getOrThrow();
      if (commit.hash == ancestor.hash) {
        return Result(true);
      }
    }
    return Result(false);
  }

  /// Independents returns a subset of the passed commits, that are not reachable the others
  /// It mimics the behavior of `git merge-base --independent commit...`.
  Result<List<GitCommit>> independents(List<GitCommit> commits) {
    commits.sort(_commitDateDec);
    _removeDuplicates(commits);

    if (commits.length < 2) {
      return Result(commits);
    }

    var seen = GitHashSet();
    var isLimit = (GitCommit commit) => seen.contains(commit.hash);

    var pos = 0;
    while (true) {
      var from = commits[pos];

      var others = List<GitCommit>.from(commits)..remove(from);

      var fromHistoryIter = commitIteratorBFSFiltered(
        objStorage: objStorage,
        from: from.hash,
        isLimit: isLimit,
      );

      for (var fromAncestorR in fromHistoryIter) {
        if (fromAncestorR.isFailure) {
          return fail(fromAncestorR);
        }
        var fromAncestor = fromAncestorR.getOrThrow();
        others.removeWhere((other) {
          if (fromAncestor.hash == other.hash) {
            var _ = commits.remove(other);
            return true;
          }
          return false;
        });

        if (commits.length == 1) {
          // FIXME: Wtf? Where are we stopping?
          throw Exception('Stop?');
        }

        var _ = seen.add(fromAncestor.hash);
      }

      pos = commits.indexOf(from) + 1;
      if (pos >= commits.length) {
        break;
      }
    }

    return Result(commits);
  }
}

int _commitDateDec(GitCommit a, GitCommit b) {
  return b.committer.date.compareTo(a.committer.date);
}

void _removeDuplicates(List<GitCommit> commits) {
  var seen = GitHashSet();
  commits.removeWhere((c) {
    var contains = seen.contains(c.hash);
    if (!contains) {
      var _ = seen.add(c.hash);
    }
    return contains;
  });
}
