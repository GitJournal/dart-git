import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/utils/date_time_tz_offset.dart';
import 'package:dart_git/utils/file_mode.dart';

/// Fetches the creation time for each blob
class BlobCTimeBuilder {
  GitRepository repo;
  final Map<GitHash, DateTimeWithTzOffset> map = {};
  final Set<GitHash> _processedTrees = {};

  BlobCTimeBuilder(this.repo);

  Future<Result<void>> build({required GitCommit from}) =>
      catchAll(() => _build(from: from));

  Future<Result<void>> _build({required GitCommit from}) async {
    var commit = from;

    var dt = DateTimeWithTzOffset.fromDt(
      commit.author.timezoneOffset / 100,
      commit.author.date,
    );

    await _processTree(commit.treeHash, dt);
    for (var parent in commit.parents) {
      var c = await repo.objStorage.readCommit(parent).getOrThrow();
      await _build(from: c).throwOnError();
    }

    return Result(null);
  }

  Future<void> _processTree(
      GitHash treeHash, DateTimeWithTzOffset commitTime) async {
    if (_processedTrees.contains(treeHash)) {
      return;
    }
    var _ = _processedTrees.add(treeHash);

    var tree = await repo.objStorage.readTree(treeHash).getOrThrow();
    for (var entry in tree.entries) {
      if (entry.mode == GitFileMode.Dir) {
        await _processTree(entry.hash, commitTime);
      } else {
        var time = commitTime;
        var et = map[entry.hash];
        if (et != null) {
          time = et.isBefore(time) ? et : time;
        }

        map[entry.hash] = time;
      }
    }
  }

  DateTimeWithTzOffset? cTime(GitHash hash) => map[hash];
}
