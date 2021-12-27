import 'dart:collection';

import 'package:path/path.dart' as p;
import 'package:tuple/tuple.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/commit_iterator.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/storage/object_storage_cache.dart';
import 'package:dart_git/utils/file_mode.dart';

abstract class TreeEntryVisitor {
  /// Return 'false' to skip this tree
  bool visitTreeEntry({
    required GitCommit commit,
    required GitTree tree,
    required GitTreeEntry entry,
    required String filePath,
  }) =>
      true;

  /// Return 'false' to skip this 'Tree'
  bool beforeTree(GitHash treeHash) => true;

  /// Return 'false' to skip this 'Commit'
  bool beforeCommit(GitHash commitHash) => true;

  void afterTree(GitTree tree) {}
  void afterCommit(GitCommit commit) {}
}

extension Visitors on GitRepository {
  Result<void> visitTree({
    required GitHash fromCommitHash,
    required TreeEntryVisitor visitor,
  }) =>
      catchAllSync(() => Result(_visitTree(fromCommitHash, visitor)));

  void _visitTree(GitHash from, TreeEntryVisitor visitor) {
    var cachedObjStorage = ObjectStorageCache(storage: objStorage);
    var iter = commitIteratorBFSFiltered(
      objStorage: cachedObjStorage,
      from: from,
      skipCommitHash: (hash) => !visitor.beforeCommit(hash),
    );
    for (var result in iter) {
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

        var tree = cachedObjStorage.readTree(treeHash).getOrThrow();
        for (var treeEntry in tree.entries) {
          var fullPath = p.join(parentPath, treeEntry.name);

          if (treeEntry.mode == GitFileMode.Dir) {
            queue.add(Tuple2(treeEntry.hash, fullPath));
            continue;
          }

          var shouldContinue = visitor.visitTreeEntry(
            commit: commit,
            tree: tree,
            entry: treeEntry,
            filePath: fullPath,
          );
          if (!shouldContinue) {
            return;
          }
        }

        visitor.afterTree(tree);
      }

      visitor.afterCommit(commit);
    }
  }
}

class MultiTreeEntryVisitor extends TreeEntryVisitor {
  final List<TreeEntryVisitor> visitors;
  final void Function(GitCommit)? afterCommitCallback;

  MultiTreeEntryVisitor(this.visitors, {this.afterCommitCallback});

  @override
  bool visitTreeEntry({
    required GitCommit commit,
    required GitTree tree,
    required GitTreeEntry entry,
    required String filePath,
  }) {
    var ret = false;
    for (var visitor in visitors) {
      ret = visitor.visitTreeEntry(
              commit: commit, tree: tree, entry: entry, filePath: filePath) ||
          ret;
    }

    return ret;
  }

  @override
  bool beforeTree(GitHash treeHash) {
    var ret = false;
    for (var visitor in visitors) {
      ret = visitor.beforeTree(treeHash) || ret;
    }

    return ret;
  }

  @override
  bool beforeCommit(GitHash commitHash) {
    var ret = false;
    for (var visitor in visitors) {
      ret = visitor.beforeCommit(commitHash) || ret;
    }

    return ret;
  }

  @override
  void afterTree(GitTree tree) {
    for (var visitor in visitors) {
      visitor.afterTree(tree);
    }
  }

  @override
  void afterCommit(GitCommit commit) {
    for (var visitor in visitors) {
      visitor.afterCommit(commit);
    }
    if (afterCommitCallback != null) {
      afterCommitCallback!(commit);
    }
  }
}
