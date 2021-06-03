import 'dart:collection';

import 'package:path/path.dart' as p;

import 'package:dart_git/diff_tree.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/storage/object_storage.dart';
import 'package:dart_git/utils/file_mode.dart';
import 'package:dart_git/utils/result.dart';

class CommitBlobChanges {
  final List<Change> added;
  final List<Change> removed;
  final List<Change> modified;

  CommitBlobChanges({
    required this.added,
    required this.removed,
    required this.modified,
  });

  bool get isEmpty => added.isEmpty && modified.isEmpty && removed.isEmpty;

  List<Change> merged() {
    return [...added, ...removed, ...modified];
  }
}

class Change {
  final ChangeEntry? from;
  final ChangeEntry? to;

  Change({required this.from, required this.to}) {
    assert(from != null || to != null);
  }

  bool get deleted => to == null;
  bool get added => from == null;
  bool get modified => to != null && from != null;

  // This could crash, no?
  String get path => from != null ? from!.path : to!.path;
  GitFileMode get mode => from != null ? from!.mode : to!.mode;

  @override
  String toString() {
    if (from == null) {
      return 'ChangeAdded{$to}';
    } else if (to == null) {
      return 'ChangeDeleted{$from}';
    } else {
      return 'ChangeModified{$from, $to}';
    }
  }
}

class ChangeEntry {
  final String path;
  final GitTree? tree;
  final GitTreeEntry? entry;

  ChangeEntry(this.path, this.tree, this.entry);

  GitHash get hash => entry!.hash;
  GitFileMode get mode => entry!.mode;

  @override
  String toString() {
    return 'ChangeEntry{path: $path, hash: $hash}';
  }
}

class _Item {
  final GitHash? fromTreeHash;
  final GitHash? fromParentHash;

  final GitHash? toTreeHash;
  final GitHash? toParentHash;

  _Item({
    required this.fromTreeHash,
    required this.fromParentHash,
    required this.toTreeHash,
    required this.toParentHash,
  });
}

Future<Result<CommitBlobChanges>> diffCommits({
  required GitCommit fromCommit,
  required GitCommit toCommit,
  required ObjectStorage objStore,
}) async {
  var addedChanges = <Change>[];
  var removedChanges = <Change>[];
  var modifiedChanges = <Change>[];

  var pathMap = <GitHash, String>{
    fromCommit.treeHash: '',
    toCommit.treeHash: '',
  };

  var queue = Queue<_Item>();
  queue.add(_Item(
    fromParentHash: null,
    toParentHash: null,
    fromTreeHash: fromCommit.treeHash,
    toTreeHash: toCommit.treeHash,
  ));

  while (queue.isNotEmpty) {
    var item = queue.removeFirst();

    if (item.fromTreeHash == item.toTreeHash) {
      continue;
    }

    GitTree? fromTree;
    GitTree? toTree;

    if (item.fromTreeHash != null) {
      var fromResult = await objStore.readTree(item.fromTreeHash!);
      if (fromResult.isFailure) {
        return fail(fromResult);
      }
      fromTree = fromResult.getOrThrow();
    }
    if (item.toTreeHash != null) {
      var toResult = await objStore.readTree(item.toTreeHash!);
      if (toResult.isFailure) {
        return fail(toResult);
      }
      toTree = toResult.getOrThrow();
    }

    var diffTreeResults = diffTree(fromTree, toTree);
    for (var result in diffTreeResults.merged()) {
      if (result.mode == GitFileMode.Dir) {
        if (result.from != null) {
          var fromParentPath = pathMap[item.fromTreeHash]!;
          var fromPath = p.join(fromParentPath, result.from!.name);

          pathMap[result.from!.hash] = fromPath;
        }
        if (result.to != null) {
          var toParentPath = pathMap[item.toTreeHash]!;
          var toPath = p.join(toParentPath, result.to!.name);

          pathMap[result.to!.hash] = toPath;
        }

        queue.add(_Item(
          fromParentHash: item.fromTreeHash,
          toParentHash: item.toTreeHash,
          fromTreeHash: result.from?.hash,
          toTreeHash: result.to?.hash,
        ));
      } else {
        if (result.modified) {
          var fromParentPath = pathMap[item.fromTreeHash]!;
          var toParentPath = pathMap[item.toTreeHash]!;

          var fromPath = p.join(fromParentPath, result.from!.name);
          var toPath = p.join(toParentPath, result.to!.name);

          var from = ChangeEntry(fromPath, fromTree, result.from);
          var to = ChangeEntry(toPath, toTree, result.to);

          assert(result.from!.hash.isNotEmpty && result.to!.hash.isNotEmpty);

          modifiedChanges.add(Change(from: from, to: to));
        } else if (result.added) {
          var toParentPath = pathMap[item.toTreeHash]!;
          var toPath = p.join(toParentPath, result.to!.name);
          var to = ChangeEntry(toPath, toTree, result.to);

          assert(result.to!.hash.isNotEmpty);

          removedChanges.add(Change(from: null, to: to));
        } else if (result.deleted) {
          var fromParentPath = pathMap[item.fromTreeHash]!;
          var fromPath = p.join(fromParentPath, result.from!.name);
          var from = ChangeEntry(fromPath, fromTree, result.from);

          assert(result.from!.hash.isNotEmpty);

          addedChanges.add(Change(from: from, to: null));
        }
      }
    }
  }

  var changes = CommitBlobChanges(
    added: addedChanges,
    removed: removedChanges,
    modified: modifiedChanges,
  );
  return Result(changes);
}

// FIXME: Paths should not start with /

// FIXME: What about when the hash is the same but just the filename has been
//        updated? That should show up as modified!
//        with R100

// FIXME: What about file mode changes?
