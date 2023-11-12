import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/utils/date_time.dart';
import 'package:dart_git/utils/git_hash_set.dart';

class FileMTimeInfo {
  String filePath;
  GitHash hash;
  GDateTime dt;

  FileMTimeInfo(this.filePath, this.hash, this.dt);

  @override
  String toString() {
    return 'FileMtimeInfo{filePath: $filePath, hash: $hash, dt: $dt}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileMTimeInfo &&
          filePath == other.filePath &&
          hash == other.hash &&
          dt == other.dt;

  @override
  int get hashCode => Object.hashAll([filePath, hash, dt]);
}

/// Fetches the last time a path was modified
class FileMTimeBuilder extends TreeEntryVisitor {
  var processedCommits = GitHashSet();
  var map = <String, FileMTimeInfo>{};

  FileMTimeBuilder({
    Set<GitHash>? processedCommits,
    Map<String, FileMTimeInfo>? map,
  }) : map = map ?? {} {
    this.processedCommits = GitHashSet.from(processedCommits);
  }

  void update(FileMTimeBuilder b) {
    processedCommits = b.processedCommits;
    map = b.map;
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
    var commitTime = commit.author.date as GDateTime;

    var changed = false;
    var info = map[filePath];
    if (info == null) {
      info = FileMTimeInfo(filePath, entry.hash, commitTime);
      changed = true;
    } else {
      if (info.hash == entry.hash) {
        if (commitTime.isBefore(info.dt)) {
          info = FileMTimeInfo(filePath, entry.hash, commitTime);
          changed = true;
        }
      } else {
        if (commitTime.isAfter(info.dt)) {
          info = FileMTimeInfo(filePath, entry.hash, commitTime);
          changed = true;
        }
      }
    }

    if (changed) {
      map[filePath] = info;
    }
    return true;
  }

  GDateTime? mTime(String filePath) => map[filePath]?.dt;
  FileMTimeInfo? info(String filePath) => map[filePath];
}
