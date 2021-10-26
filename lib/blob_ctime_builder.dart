import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/utils/date_time_tz_offset.dart';

/// Fetches the creation time for each blob
class BlobCTimeBuilder extends TreeEntryVisitor {
  var processedTrees = <GitHash>{};
  var processedCommits = <GitHash>{};
  var map = <GitHash, DateTimeWithTzOffset>{};

  BlobCTimeBuilder({
    Set<GitHash>? processedTrees,
    Set<GitHash>? processedCommits,
    Map<GitHash, DateTimeWithTzOffset>? map,
  })  : processedTrees = processedTrees ?? {},
        processedCommits = processedCommits ?? {},
        map = map ?? {};

  @override
  bool beforeTree(GitHash treeHash) => !processedTrees.contains(treeHash);

  @override
  void afterTree(GitTree tree) {
    var _ = processedTrees.add(tree.hash);
  }

  @override
  bool beforeCommit(GitHash commitHash) =>
      !processedCommits.contains(commitHash);

  @override
  void afterCommit(GitCommit commit) {
    var _ = processedCommits.add(commit.hash);
  }

  @override
  Future<bool> visitTreeEntry({
    required GitCommit commit,
    required GitTree tree,
    required GitTreeEntry entry,
    required String filePath,
  }) async {
    final commitTime = commit.author.dateWithOffset;

    var time = commitTime;
    var et = map[entry.hash];
    if (et != null) {
      time = et.isBefore(time) ? et : time;
    }

    map[entry.hash] = time;
    return true;
  }

  DateTimeWithTzOffset? cTime(GitHash hash) => map[hash];
}
