import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/objects/commit.dart';

extension MergeBase on GitRepository {
  List<GitCommit> mergeBase(GitCommit a, GitCommit b) {
    return [a];
  }
}
