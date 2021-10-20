import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/utils/date_time_tz_offset.dart';

/// Fetches the creation time for each blob
class BlobCTimeBuilder extends TreeEntryVisitor {
  final Map<GitHash, DateTimeWithTzOffset> map = {};
  final Set<GitHash> _processedTrees = {};

  @override
  bool beforeTree(GitHash treeHash) {
    var c = _processedTrees.contains(treeHash);

    // skip if already processed
    return !c;
  }

  @override
  void afterTree(GitTree tree) {
    var _ = _processedTrees.add(tree.hash);
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
    var et = map[entry.hash];
    if (et != null) {
      time = et.isBefore(time) ? et : time;
    }

    map[entry.hash] = time;
    return true;
  }

  DateTimeWithTzOffset? cTime(GitHash hash) => map[hash];
}
