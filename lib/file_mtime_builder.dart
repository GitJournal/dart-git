import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/utils/date_time.dart';
import 'package:dart_git/vistors.dart';

class FileMTimeInfo {
  String filePath;
  GitHash hash;
  GDateTime dt;

  FileMTimeInfo(this.filePath, this.hash, this.dt);

  @override
  String toString() {
    return 'FileMtimeInfo{filePath: $filePath, hash: $hash, dt: $dt}';
  }
}

/// Fetches the last time a path was modified
class FileMTimeBuilder extends TreeEntryVisitor {
  var processedTrees = <GitHash>{};
  var processedCommits = <GitHash>{};
  var map = <String, FileMTimeInfo>{};

  FileMTimeBuilder({
    Set<GitHash>? processedTrees,
    Set<GitHash>? processedCommits,
    Map<String, FileMTimeInfo>? map,
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
    var commitTime = commit.author.dateWithOffset;

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

  GDateTime? mTime(String filePath) => map[filePath]?.dt;
  FileMTimeInfo? info(String filePath) => map[filePath];
}
