import 'dart:collection';

import 'package:path/path.dart' as p;

import 'package:dart_git/diff_tree.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/storage/interfaces.dart';
import 'package:dart_git/utils/file_mode.dart';
import 'package:dart_git/utils/result.dart';

class CommitBlobChanges {
  final List<Change> add;
  final List<Change> remove;
  final List<Change> modify;

  CommitBlobChanges({
    required this.add,
    required this.remove,
    required this.modify,
  });

  bool get isEmpty => add.isEmpty && modify.isEmpty && remove.isEmpty;

  List<Change> merged() {
    return [...add, ...remove, ...modify];
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

  final GitHash? toTreeHash;
  final GitHash? toParentHash;

  _Item({
    required this.fromTreeHash,
    required this.fromParentHash,
    required this.toTreeHash,
    required this.toParentHash,
  });
}

/// Returns the changes that once applied on `fromCommit` to transform
/// it to `toCommit`
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

    var diffTreeResults = diffTree(from: fromTree, to: toTree);
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
        if (result.modify) {
          var fromParentPath = pathMap[item.fromTreeHash]!;
          var toParentPath = pathMap[item.toTreeHash]!;

          var fromPath = p.join(fromParentPath, result.from!.name);
          var toPath = p.join(toParentPath, result.to!.name);

          var from = ChangeEntry(fromPath, fromTree, result.from);
          var to = ChangeEntry(toPath, toTree, result.to);

          assert(result.from!.hash.isNotEmpty && result.to!.hash.isNotEmpty);

          modifiedChanges.add(Change(from: from, to: to));
        } else if (result.add) {
          var toParentPath = pathMap[item.toTreeHash]!;
          var toPath = p.join(toParentPath, result.to!.name);
          var to = ChangeEntry(toPath, toTree, result.to);

          assert(result.to!.hash.isNotEmpty);

          removedChanges.add(Change(from: null, to: to));
        } else if (result.delete) {
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
    add: addedChanges,
    remove: removedChanges,
    modify: modifiedChanges,
  );
  return Result(changes);
}

// FIXME: Paths should not start with /

// FIXME: What about when the hash is the same but just the filename has been
//        updated? That should show up as modified!
//        with R100

// FIXME: What about file mode changes?
