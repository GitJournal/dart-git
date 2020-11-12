import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/tree.dart';

import 'package:meta/meta.dart';

class DiffTreeItem {
  final String path;
  final GitFileMode prevMode;
  final GitFileMode newMode;

  final GitHash prevHash;
  final GitHash newHash;

  DiffTreeItem({
    @required GitTreeLeaf leaf,
    @required GitTreeLeaf newLeaf,
  })  : path = leaf != null ? leaf.path : newLeaf.path,
        prevMode = leaf != null ? leaf.mode : GitFileMode(0),
        prevHash = leaf != null ? leaf.hash : GitHash.zero(),
        newMode = newLeaf != null ? newLeaf.mode : GitFileMode(0),
        newHash = newLeaf != null ? newLeaf.hash : GitHash.zero() {
    if (leaf != null && newLeaf != null) {
      assert(leaf.path == newLeaf.path);
    }
  }
}

List<DiffTreeItem> diffTree(GitTree ta, GitTree tb) {
  var aPaths = <String, GitTreeLeaf>{};
  var aPathSet = <String>{};
  for (var leaf in ta.leaves) {
    aPathSet.add(leaf.path);
    aPaths[leaf.path] = leaf;
  }

  var bPaths = <String, GitTreeLeaf>{};
  var bPathSet = <String>{};
  for (var leaf in tb.leaves) {
    bPathSet.add(leaf.path);
    bPaths[leaf.path] = leaf;
  }

  var results = <DiffTreeItem>[];

  var removed = aPathSet.difference(bPathSet);
  for (var path in removed) {
    var item = DiffTreeItem(leaf: aPaths[path], newLeaf: null);
    results.add(item);
  }

  var added = bPathSet.difference(aPathSet);
  for (var path in added) {
    var item = DiffTreeItem(leaf: null, newLeaf: bPaths[path]);
    results.add(item);
  }

  var maybeModified = aPathSet.intersection(bPathSet);
  for (var path in maybeModified) {
    var aLeaf = aPaths[path];
    var bLeaf = bPaths[path];
    if (aLeaf.mode != bLeaf.mode || aLeaf.hash != bLeaf.hash) {
      var item = DiffTreeItem(leaf: aLeaf, newLeaf: bLeaf);
      results.add(item);
    }
  }

  return results;
}
