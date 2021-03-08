import 'package:dart_git/dart_git.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/commit_iterator.dart';
import 'package:dart_git/plumbing/objects/commit.dart';

extension MergeBase on GitRepository {
  List<GitCommit> mergeBase(GitCommit a, GitCommit b) {
    return [a];
  }

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

      await for (var fromAncestor in fromHistoryIter) {
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
