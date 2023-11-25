import 'dart:collection';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/diff_tree.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/storage/interfaces.dart';
import 'package:dart_git/utils/file_mode.dart';

class CommitBlobChanges {
  final IList<Change> add;
  final IList<Change> remove;
  final IList<Change> modify;

  CommitBlobChanges({
    required Iterable<Change> add,
    required Iterable<Change> remove,
    required Iterable<Change> modify,
  })  : add = add.toIList(),
        remove = remove.toIList(),
        modify = modify.toIList();

  bool get isEmpty => add.isEmpty && modify.isEmpty && remove.isEmpty;

  List<Change> merged() {
    return [...add, ...remove, ...modify];
  }

  @override
  String toString() {
    return 'CommitBlobChanges{\nadd: $add\nremove: $remove\nmodify: $modify';
  }
}

/// Applying this change on 'from' will produce 'to'.
class Change {
  final ChangeEntry? from;
  final ChangeEntry? to;

  Change({required this.from, required this.to}) {
    assert(from != null || to != null);
  }

  bool get delete => to == null;
  bool get add => from == null;
  bool get modify => to != null && from != null;

  String get path => from != null ? from!.path : to!.path;
  GitFileMode get mode => from != null ? from!.mode : to!.mode;
  GitHash get hash => from != null ? from!.hash : to!.hash;

  @override
  String toString() {
    if (from == null) {
      return 'ChangeAdd{$to}';
    } else if (to == null) {
      return 'ChangeDelete{$from}';
    } else {
      return 'ChangeModify{$from, $to}';
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

  final String? fromTreePath;
  final String? toTreePath;

  final GitHash? toTreeHash;
  final GitHash? toParentHash;

  _Item({
    required this.fromTreeHash,
    required this.fromParentHash,
    required this.toTreeHash,
    required this.toParentHash,
    required this.fromTreePath,
    required this.toTreePath,
  });

  @override
  String toString() {
    return '_Item{fromTreeHash: $fromTreeHash, fromParentHash: $fromParentHash, fromTreePath: $fromTreePath, toTreePath: $toTreePath, toTreeHash: $toTreeHash, toParentHash: $toParentHash}';
  }
}

/// Returns the changes that once applied on `fromCommit` to transform
/// it to `toCommit`
CommitBlobChanges diffCommits({
  required GitCommit fromCommit,
  required GitCommit toCommit,
  required ObjectStorage objStore,
}) {
  var addedChanges = <Change>[];
  var removedChanges = <Change>[];
  var modifiedChanges = <Change>[];

  var queue = Queue<_Item>();
  queue.add(_Item(
    fromParentHash: null,
    toParentHash: null,
    fromTreePath: '',
    toTreePath: '',
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
      fromTree = objStore.readTree(item.fromTreeHash!);
    }
    if (item.toTreeHash != null) {
      toTree = objStore.readTree(item.toTreeHash!);
    }

    var diffTreeResults = diffTree(from: fromTree, to: toTree);
    for (var result in diffTreeResults.merged()) {
      if (result.mode == GitFileMode.Dir) {
        String? fromTreePath;
        String? toTreePath;

        if (result.from != null) {
          fromTreePath = p.join(item.fromTreePath!, result.from!.name);
        }
        if (result.to != null) {
          toTreePath = p.join(item.toTreePath!, result.to!.name);
        }

        queue.add(_Item(
          fromParentHash: item.fromTreeHash,
          toParentHash: item.toTreeHash,
          fromTreePath: fromTreePath,
          toTreePath: toTreePath,
          fromTreeHash: result.from?.hash,
          toTreeHash: result.to?.hash,
        ));
      } else {
        if (result.modify) {
          var fromPath = p.join(item.fromTreePath!, result.from!.name);
          var toPath = p.join(item.toTreePath!, result.to!.name);

          var from = ChangeEntry(fromPath, fromTree, result.from);
          var to = ChangeEntry(toPath, toTree, result.to);

          assert(result.from!.hash.isNotEmpty && result.to!.hash.isNotEmpty);

          modifiedChanges.add(Change(from: from, to: to));
        } else if (result.add) {
          var toPath = p.join(item.toTreePath!, result.to!.name);
          var to = ChangeEntry(toPath, toTree, result.to);

          assert(result.to!.hash.isNotEmpty);

          addedChanges.add(Change(from: null, to: to));
        } else if (result.delete) {
          var fromPath = p.join(item.fromTreePath!, result.from!.name);
          var from = ChangeEntry(fromPath, fromTree, result.from);

          assert(result.from!.hash.isNotEmpty);

          removedChanges.add(Change(from: from, to: null));
        }
      }
    }
  }

  var changes = CommitBlobChanges(
    add: addedChanges,
    remove: removedChanges,
    modify: modifiedChanges,
  );
  return changes;
}

// FIXME: Paths should not start with /

// FIXME: What about when the hash is the same but just the filename has been
//        updated? That should show up as modified!
//        with R100

// FIXME: What about file mode changes?
