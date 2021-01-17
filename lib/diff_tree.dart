import 'package:dart_git/plumbing/objects/tree.dart';

import 'package:meta/meta.dart';

class DiffTreeChange {
  final GitTreeEntry from;
  final GitTreeEntry to;

  DiffTreeChange({
    @required this.from,
    @required this.to,
  });

  bool get deleted => to == null;
  bool get added => from == null;
  bool get modified => to != null && from != null;
}

class DiffTreeResults {
  final List<DiffTreeChange> added;
  final List<DiffTreeChange> modified;
  final List<DiffTreeChange> removed;

  DiffTreeResults({
    @required this.added,
    @required this.modified,
    @required this.removed,
  });

  bool get isEmpty => added.isEmpty && modified.isEmpty && removed.isEmpty;

  List<DiffTreeChange> merged() {
    return [...added, ...removed, ...modified];
  }
}

DiffTreeResults diffTree(GitTree ta, GitTree tb) {
  var aPaths = <String, GitTreeEntry>{};
  var aPathSet = <String>{};
  for (var leaf in ta.entries) {
    aPathSet.add(leaf.name);
    aPaths[leaf.name] = leaf;
  }

  var bPaths = <String, GitTreeEntry>{};
  var bPathSet = <String>{};
  for (var leaf in tb.entries) {
    bPathSet.add(leaf.name);
    bPaths[leaf.name] = leaf;
  }

  var addedItems = <DiffTreeChange>[];
  var removedItems = <DiffTreeChange>[];
  var modifiedItems = <DiffTreeChange>[];

  var removed = aPathSet.difference(bPathSet);
  for (var path in removed) {
    var item = DiffTreeChange(from: aPaths[path], to: null);
    removedItems.add(item);
  }

  var added = bPathSet.difference(aPathSet);
  for (var path in added) {
    var item = DiffTreeChange(from: null, to: bPaths[path]);
    addedItems.add(item);
  }

  var maybeModified = aPathSet.intersection(bPathSet);
  for (var path in maybeModified) {
    var aLeaf = aPaths[path];
    var bLeaf = bPaths[path];
    if (aLeaf.mode != bLeaf.mode || aLeaf.hash != bLeaf.hash) {
      var item = DiffTreeChange(from: aLeaf, to: bLeaf);
      modifiedItems.add(item);
    }
  }

  return DiffTreeResults(
      added: addedItems, modified: modifiedItems, removed: removedItems);
}
