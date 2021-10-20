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
class FileMTimeBuilder implements TreeEntryVisitor {
  final Map<String, FileMTimeInfo> map = {};
  final Set<GitHash> _processedTrees = {};

  @override
  bool beforeTree(GitHash treeHash) {
    var c = _processedTrees.contains(treeHash);
    var _ = _processedTrees.add(treeHash);

    // skip if already processed
    return !c;
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

    var info = map[filePath];
    if (info == null) {
      info = FileMTimeInfo(filePath, entry.hash, commitTime);
    } else {
      if (info.hash == entry.hash) {
        if (commitTime.isAfter(info.dt)) {
          info = FileMTimeInfo(filePath, entry.hash, commitTime);
        }
      }
    }

    map[filePath] = info;
    return true;
  }

  DateTimeWithTzOffset? mTime(String filePath) => map[filePath]?.dt;
  FileMTimeInfo? info(String filePath) => map[filePath];
}
