import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/utils/file_mode.dart';

class DiffTreeChange {
  final GitTreeEntry? from;
  final GitTreeEntry? to;

  DiffTreeChange({
    required this.from,
    required this.to,
  });

  bool get deleted => to == null;
  bool get added => from == null;
  bool get modified => to != null && from != null;

  String get name => from != null ? from!.name : to!.name;
  GitFileMode get mode => from != null ? from!.mode : to!.mode;
}

class DiffTreeResults {
  final List<DiffTreeChange> added;
  final List<DiffTreeChange> modified;
  final List<DiffTreeChange> removed;

  DiffTreeResults({
    required this.added,
    required this.modified,
    required this.removed,
  });

  bool get isEmpty => added.isEmpty && modified.isEmpty && removed.isEmpty;

  List<DiffTreeChange> merged() {
    return [...added, ...removed, ...modified];
  }
}

DiffTreeResults diffTree(GitTree? ta, GitTree? tb) {
  if (ta == null && tb == null) {
    return DiffTreeResults(added: [], modified: [], removed: []);
  }

  if (ta == null) {
    var removed = tb!.entries.map((e) => DiffTreeChange(from: null, to: e));
    return DiffTreeResults(added: [], modified: [], removed: removed.toList());
  } else if (tb == null) {
    var added = ta.entries.map((e) => DiffTreeChange(from: e, to: null));
    return DiffTreeResults(added: added.toList(), modified: [], removed: []);
  }

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
    assert(item.deleted);
    removedItems.add(item);
  }

  var added = bPathSet.difference(aPathSet);
  for (var path in added) {
    var item = DiffTreeChange(from: null, to: bPaths[path]);
    assert(item.added);
    addedItems.add(item);
  }

  var maybeModified = aPathSet.intersection(bPathSet);
  for (var path in maybeModified) {
    var aLeaf = aPaths[path]!;
    var bLeaf = bPaths[path]!;
    if (aLeaf.mode != bLeaf.mode || aLeaf.hash != bLeaf.hash) {
      var item = DiffTreeChange(from: aLeaf, to: bLeaf);
      assert(item.modified);
      modifiedItems.add(item);
    }
  }

  return DiffTreeResults(
      added: addedItems, modified: modifiedItems, removed: removedItems);
}
