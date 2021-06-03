import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/commit_iterator.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';

extension MergeBase on GitRepository {
  /// mergeBase mimics the behavior of `git merge-base actual other`, returning the
  /// best common ancestor between the actual and the passed one.
  /// The best common ancestors can not be reached from other common ancestors.
  Future<List<GitCommit>> mergeBase(GitCommit a, GitCommit b) async {
    var clist = [a, b];
    clist.sort(_commitDateDec);

    var newer = clist[0];
    var older = clist[1];

    var newerHistory = await allAncestors(newer, shouldNotContain: older);
    if (newerHistory == null) {
      return [older];
    }

    var inNewerHistory = (GitCommit c) => newerHistory.contains(c.hash);

    var results = <GitCommit>[];
    var iter = commitIteratorBFSFiltered(
      objStorage: objStorage,
      from: older,
      isValid: inNewerHistory,
      isLimit: inNewerHistory,
    );
    await for (var r in iter) {
      var commit = r.getOrThrow();
      results.add(commit);
    }

    return independents(results);
  }

  Future<Set<GitHash>?> allAncestors(
    GitCommit start, {
    required GitCommit shouldNotContain,
  }) async {
    if (start.hash == shouldNotContain.hash) null;

    var all = <GitHash>{};
    var iter = commitIteratorBFS(objStorage: objStorage, from: start);
    await for (var commitR in iter) {
      var commit = commitR.getOrThrow();
      if (commit.hash == shouldNotContain.hash) {
        return null;
      }

      all.add(commit.hash);
    }

    return all;
  }

  /// isAncestor returns true if the actual commit is ancestor of the passed one.
  /// It returns an error if the history is not transversable
  /// It mimics the behavior of `git merge --is-ancestor actual other`
  Future<bool> isAncestor(GitCommit ancestor, GitCommit child) async {
    var iter = commitPreOrderIterator(objStorage: objStorage, from: child);
    await for (var commitR in iter) {
      var commit = commitR.getOrThrow();
      if (commit.hash == ancestor.hash) {
        return true;
      }
    }
    return false;
  }

  /// Independents returns a subset of the passed commits, that are not reachable the others
  /// It mimics the behavior of `git merge-base --independent commit...`.
  Future<List<GitCommit>> independents(List<GitCommit> commits) async {
    commits.sort(_commitDateDec);
    _removeDuplicates(commits);

    if (commits.length < 2) {
      return commits;
    }

    var seen = <GitHash>{};
    var isLimit = (GitCommit commit) => seen.contains(commit.hash);

    var pos = 0;
    while (true) {
      var from = commits[pos];

      var others = List<GitCommit>.from(commits);
      others.remove(from);

      var fromHistoryIter = commitIteratorBFSFiltered(
        objStorage: objStorage,
        from: from,
        isLimit: isLimit,
      );

      await for (var fromAncestorR in fromHistoryIter) {
        var fromAncestor = fromAncestorR.getOrThrow();
        others.removeWhere((other) {
          if (fromAncestor.hash == other.hash) {
            commits.remove(other);
            return true;
          }
          return false;
        });

        if (commits.length == 1) {
          throw Exception('Stop?');
        }

        seen.add(fromAncestor.hash);
      }

      pos = commits.indexOf(from) + 1;
      if (pos >= commits.length) {
        break;
      }
    }

    return commits;
  }
}

int _commitDateDec(GitCommit a, GitCommit b) {
  return b.committer.date.compareTo(a.committer.date);
}

void _removeDuplicates(List<GitCommit> commits) {
  var seen = <GitHash>{};
  commits.removeWhere((c) {
    var contains = seen.contains(c.hash);
    if (!contains) {
      seen.add(c.hash);
    }
    return contains;
  });
}
