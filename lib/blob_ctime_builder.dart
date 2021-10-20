import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/utils/date_time_tz_offset.dart';

/// Fetches the creation time for each blob
class BlobCTimeBuilder extends TreeEntryVisitor {
  final BlobCTimeBuilderData data;

  BlobCTimeBuilder({BlobCTimeBuilderData? data})
      : data = data ?? BlobCTimeBuilderData();

  @override
  bool beforeTree(GitHash treeHash) => !data.processedTrees.contains(treeHash);

  @override
  void afterTree(GitTree tree) {
    var _ = data.processedTrees.add(tree.hash);
  }

  @override
  bool beforeCommit(GitHash commitHash) =>
      !data.processedCommits.contains(commitHash);

  @override
  void afterCommit(GitCommit commit) {
    var _ = data.processedCommits.add(commit.hash);
  }

  @override
  Future<bool> visitTreeEntry({
    required GitCommit commit,
    required GitTree tree,
    required GitTreeEntry entry,
    required String filePath,
  }) async {
    final commitTime = DateTimeWithTzOffset.fromDt(
      commit.author.timezoneOffset / 100.0,
      commit.author.date,
    );

    var time = commitTime;
    var et = data.map[entry.hash];
    if (et != null) {
      time = et.isBefore(time) ? et : time;
    }

    data.map[entry.hash] = time;
    return true;
  }

  DateTimeWithTzOffset? cTime(GitHash hash) => data.map[hash];
}

class BlobCTimeBuilderData {
  var processedTrees = <GitHash>{};
  var processedCommits = <GitHash>{};
  var map = <GitHash, DateTimeWithTzOffset>{};
}
