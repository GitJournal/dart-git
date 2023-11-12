import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/utils/file_mode.dart';

class DiffTreeChange {
  final GitTreeEntry? from;
  final GitTreeEntry? to;

  DiffTreeChange({
    required this.from,
    required this.to,
  }) {
    assert(from != null || to != null);
  }

  bool get delete => to == null;
  bool get add => from == null;
  bool get modify => to != null && from != null;

  String get name => from != null ? from!.name : to!.name;
  GitFileMode get mode => from != null ? from!.mode : to!.mode;

  @override
  String toString() => 'DiffTreeChange{from: $from, to: $to}';
}

/// Change which should be applied on a tree to transform it to another tree
class DiffTreeResults {
  final List<DiffTreeChange> add;
  final List<DiffTreeChange> modify;
  final List<DiffTreeChange> remove;

  DiffTreeResults({
    required this.add,
    required this.modify,
    required this.remove,
  });

  bool get isEmpty => add.isEmpty && modify.isEmpty && remove.isEmpty;

  List<DiffTreeChange> merged() {
    return [...add, ...remove, ...modify];
  }
}

/// Gives a list of changes that when applied on `from` will produce `to`.
DiffTreeResults diffTree({required GitTree? from, required GitTree? to}) {
  if (from == null && to == null) {
    return DiffTreeResults(add: [], modify: [], remove: []);
  }

  if (from == null) {
    var add = to!.entries.map((e) => DiffTreeChange(from: null, to: e));
    return DiffTreeResults(add: add.toList(), modify: [], remove: []);
  } else if (to == null) {
    var remove = from.entries.map((e) => DiffTreeChange(from: e, to: null));
    return DiffTreeResults(add: [], modify: [], remove: remove.toList());
  }

  var aPaths = <String, GitTreeEntry>{};
  var aPathSet = <String>{};
  for (var leaf in from.entries) {
    aPathSet.add(leaf.name);
    aPaths[leaf.name] = leaf;
  }

  var bPaths = <String, GitTreeEntry>{};
  var bPathSet = <String>{};
  for (var leaf in to.entries) {
    bPathSet.add(leaf.name);
    bPaths[leaf.name] = leaf;
  }

  var addedItems = <DiffTreeChange>[];
  var removedItems = <DiffTreeChange>[];
  var modifiedItems = <DiffTreeChange>[];

  var added = bPathSet.difference(aPathSet);
  for (var path in added) {
    var item = DiffTreeChange(from: null, to: bPaths[path]);
    assert(item.add);
    addedItems.add(item);
  }

  var removed = aPathSet.difference(bPathSet);
  for (var path in removed) {
    var item = DiffTreeChange(from: aPaths[path], to: null);
    assert(item.delete);
    removedItems.add(item);
  }

  var maybeModified = aPathSet.intersection(bPathSet);
  for (var path in maybeModified) {
    var aLeaf = aPaths[path]!;
    var bLeaf = bPaths[path]!;
    if (aLeaf.mode != bLeaf.mode || aLeaf.hash != bLeaf.hash) {
      var item = DiffTreeChange(from: aLeaf, to: bLeaf);
      assert(item.modify);
      modifiedItems.add(item);
    }
  }

  return DiffTreeResults(
    add: addedItems,
    modify: modifiedItems,
    remove: removedItems,
  );
}
