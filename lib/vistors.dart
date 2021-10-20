import 'dart:collection';

import 'package:path/path.dart' as p;
import 'package:tuple/tuple.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/commit_iterator.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/utils/file_mode.dart';

class TreeEntryVisitor {
  /// Return 'false' to skip this tree
  Future<bool> visitTreeEntry({
    required GitCommit commit,
    required GitTree tree,
    required GitTreeEntry entry,
    required String filePath,
  }) async =>
      false;

  /// Return 'false' to skip this 'Tree'
  bool beforeTree(GitHash treeHash) => true;

  /// Return 'false' to skip this 'Commit'
  // bool beforeCommit(GitHash commitHash) => false;
}

extension Visitors on GitRepository {
  Future<Result<void>> visitTree({
    required GitHash fromCommitHash,
    required TreeEntryVisitor visitor,
  }) async =>
      catchAll(() async => Result(await _visitTree(fromCommitHash, visitor)));

  Future<void> _visitTree(GitHash from, TreeEntryVisitor visitor) async {
    var iter = commitIteratorBFS(objStorage: objStorage, from: from);
    await for (var result in iter) {
      var commit = result.getOrThrow();

      var queue = Queue<Tuple2<GitHash, String>>();
      queue.add(Tuple2(commit.treeHash, ''));

      while (queue.isNotEmpty) {
        var qt = queue.removeFirst();
        var treeHash = qt.item1;
        var parentPath = qt.item2;

        if (!visitor.beforeTree(treeHash)) {
          continue;
        }

        var tree = await objStorage.readTree(treeHash).getOrThrow();
        for (var treeEntry in tree.entries) {
          var fullPath = p.join(parentPath, treeEntry.name);

          if (treeEntry.mode == GitFileMode.Dir) {
            queue.add(Tuple2(treeEntry.hash, fullPath));
            continue;
          }

          var shouldContinue = await visitor.visitTreeEntry(
            commit: commit,
            tree: tree,
            entry: treeEntry,
            filePath: fullPath,
          );
          if (!shouldContinue) {
            return;
          }
        }
      }
    }
  }
}
