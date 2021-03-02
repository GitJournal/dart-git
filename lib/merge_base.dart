import 'package:dart_git/dart_git.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';

extension MergeBase on GitRepository {
  List<GitCommit> mergeBase(GitCommit a, GitCommit b) {
    return [a];
  }

  List<GitCommit> independents(List<GitCommit> commits) {
    commits.sort(_commitDateDec);
    _removeDuplicates(commits);

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
    print('${c.hash} $contains -- $seen ${seen.contains(c.hash)}');
    if (!contains) {
      seen.add(c.hash);
    }
    return contains;
  });
}
