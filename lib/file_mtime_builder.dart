import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/utils/date_time_tz_offset.dart';
import 'package:dart_git/vistors.dart';

class FileMTimeInfo {
  String filePath;
  GitHash hash;
  DateTimeWithTzOffset dt;

  FileMTimeInfo(this.filePath, this.hash, this.dt);

  @override
  String toString() {
    return 'FileMtimeInfo{filePath: $filePath, hash: $hash, dt: $dt}';
  }
}

/// Fetches the last time a path was modified
class FileMTimeBuilder extends TreeEntryVisitor {
  final FileMTimeBuilderData data;

  FileMTimeBuilder({FileMTimeBuilderData? data})
      : data = data ?? FileMTimeBuilderData();

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
    var commitTime = DateTimeWithTzOffset.fromDt(
      commit.author.timezoneOffset / 100.0,
      commit.author.date,
    );

    var info = data.map[filePath];
    if (info == null) {
      info = FileMTimeInfo(filePath, entry.hash, commitTime);
    } else {
      if (info.hash == entry.hash) {
        if (commitTime.isAfter(info.dt)) {
          info = FileMTimeInfo(filePath, entry.hash, commitTime);
        }
      }
    }

    data.map[filePath] = info;
    return true;
  }

  DateTimeWithTzOffset? mTime(String filePath) => data.map[filePath]?.dt;
  FileMTimeInfo? info(String filePath) => data.map[filePath];
}

class FileMTimeBuilderData {
  var processedTrees = <GitHash>{};
  var processedCommits = <GitHash>{};
  var map = <String, FileMTimeInfo>{};
}
