import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/utils/date_time_tz_offset.dart';
import 'package:dart_git/utils/file_mode.dart';

import 'package:path/path.dart' as p;

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
class FileMTimeBuilder {
  GitRepository repo;
  final Map<String, FileMTimeInfo> map = {};
  final Set<GitHash> _processedTrees = {};

  FileMTimeBuilder(this.repo);

  Future<Result<void>> build({required GitCommit from}) =>
      catchAll(() => _build(from: from));

  Future<Result<void>> _build({required GitCommit from}) async {
    var commit = from;

    var dt = DateTimeWithTzOffset.fromDt(
      commit.author.timezoneOffset / 100.0,
      commit.author.date,
    );

    // Go over all the co
    await _processTree(commit.treeHash, dt, '');
    for (var parent in commit.parents) {
      var c = await repo.objStorage.readCommit(parent).getOrThrow();
      await _build(from: c).throwOnError();
    }

    return Result(null);
  }

  Future<void> _processTree(GitHash treeHash, DateTimeWithTzOffset commitTime,
      String parentPath) async {
    if (_processedTrees.contains(treeHash)) {
      return;
    }
    var _ = _processedTrees.add(treeHash);

    var tree = await repo.objStorage.readTree(treeHash).getOrThrow();
    for (var entry in tree.entries) {
      if (entry.mode == GitFileMode.Dir) {
        var path = p.join(parentPath, entry.name);
        await _processTree(entry.hash, commitTime, path);
      } else {
        var filePath = p.join(parentPath, entry.name);
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
      }
    }
  }

  DateTimeWithTzOffset? mTime(String filePath) => map[filePath]?.dt;
  FileMTimeInfo? info(String filePath) => map[filePath];
}
