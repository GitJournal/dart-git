import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/utils/date_time.dart';
import 'package:dart_git/utils/git_hash_set.dart';

/// Fetches the creation time for each blob
class BlobCTimeBuilder extends TreeEntryVisitor {
  var processedTrees = GitHashSet();
  var processedCommits = GitHashSet();
  var map = <GitHash, GDateTime>{};

  BlobCTimeBuilder({
    Set<GitHash>? processedTrees,
    Set<GitHash>? processedCommits,
    Map<GitHash, GDateTime>? map,
  }) : map = map ?? {} {
    this.processedCommits = GitHashSet.from(processedCommits);
    this.processedTrees = GitHashSet.from(processedTrees);
  }

  void update(BlobCTimeBuilder b) {
    processedTrees = b.processedTrees;
    processedCommits = b.processedCommits;
    map = b.map;
  }

  @override
  bool beforeTree(GitHash treeHash) => !processedTrees.contains(treeHash);

  @override
  void afterTree(GitTree tree) {
    processedTrees.add(tree.hash);
  }

  @override
  bool beforeCommit(GitHash commitHash) =>
      !processedCommits.contains(commitHash);

  @override
  void afterCommit(GitCommit commit) {
    processedCommits.add(commit.hash);
  }

  @override
  bool visitTreeEntry({
    required GitCommit commit,
    required GitTree tree,
    required GitTreeEntry entry,
    required String filePath,
  }) {
    final commitTime = commit.author.date as GDateTime;

    var time = commitTime;
    var et = map[entry.hash];
    if (et != null) {
      time = et.isBefore(time) ? et : time;
    }

    map[entry.hash] = time;
    return true;
  }

  GDateTime? cTime(GitHash hash) => map[hash];
}
