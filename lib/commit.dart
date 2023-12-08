import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/utils/file_mode.dart';

extension Commit on GitRepository {
  /// Exceptions -
  /// * GitEmptyCommit
  GitCommit commit({
    required String message,
    required GitAuthor author,
    GitAuthor? committer,
    bool addAll = false,
  }) {
    committer ??= author;

    if (addAll) {
      add(workTree);
    }

    var index = indexStorage.readIndex();

    var treeHash = writeTree(index);
    var parents = <GitHash>[];

    try {
      var headRef = head();
      var parentRef = resolveReference(headRef);
      parents.add(parentRef.hash);
    } on GitMissingHEAD {
      // This is the first commit
    } on GitRefNotFound {
      // This is the first commit
    }

    for (var parent in parents) {
      var parentCommit = objStorage.readCommit(parent);
      if (parentCommit.treeHash == treeHash) {
        throw GitEmptyCommit();
      }
    }

    var commit = GitCommit.create(
      author: author,
      committer: committer,
      parents: parents,
      message: message,
      treeHash: treeHash,
    );
    var hash = objStorage.writeObject(commit);

    // Update the ref of the current branch
    var branchName = currentBranch();
    var newRef = HashReference(ReferenceName.branch(branchName), hash);
    refStorage.saveRef(newRef);

    return commit;
  }

  GitHash writeTree(GitIndex index) {
    var allTreeDirs = {''};
    var treeObjects = {'': GitTree.create()};

    for (var entry in index.entries) {
      var fullPath = entry.path;

      var fileName = p.basename(fullPath);
      var dirName = p.dirname(fullPath);

      // Construct all the tree objects
      var allDirs = <String>[];
      while (dirName != '.') {
        allTreeDirs.add(dirName);
        allDirs.add(dirName);

        dirName = p.dirname(dirName);
      }

      allDirs.sort(dirSortFunc);

      for (var dir in allDirs) {
        if (!treeObjects.containsKey(dir)) {
          treeObjects[dir] = GitTree.create();
        }

        var parentDir = p.dirname(dir);
        if (parentDir == '.') parentDir = '';

        var parentTreeEntries = treeObjects[parentDir]!.entries.unlock;
        var folderName = p.basename(dir);

        var i = parentTreeEntries.indexWhere((e) => e.name == folderName);
        if (i != -1) {
          continue;
        }
        parentTreeEntries.add(GitTreeEntry(
          mode: GitFileMode.Dir,
          name: folderName,
          hash: GitHash.zero(),
        ));

        var parentTree = GitTree.create(parentTreeEntries);
        treeObjects[parentDir] = parentTree;
      }

      dirName = p.dirname(fullPath);
      if (dirName == '.') {
        dirName = '';
      }

      var leaf = GitTreeEntry(
        mode: entry.mode,
        name: fileName,
        hash: entry.hash,
      );
      treeObjects[dirName] = GitTree.create(
        treeObjects[dirName]!.entries.add(leaf),
      );
    }
    assert(treeObjects.containsKey(''));

    // Write all the tree objects
    var hashMap = <String, GitHash>{};

    // sort dir paths by number of slashes
    var allDirs = allTreeDirs.toList();
    allDirs.sort(dirSortFunc);

    // `reversed`-> start with the deepest folders as we need the hash of
    // all the sub-folders before we can write the parent folder.
    for (var dir in allDirs.reversed) {
      var tree = treeObjects[dir]!;
      var entries = tree.entries.unlock;
      assert(entries.isNotEmpty);

      for (var i = 0; i < entries.length; i++) {
        var leaf = entries[i];

        if (leaf.hash.isNotEmpty) {
          // Making sure the leaf is a blob.
          // This is slow because it reads every leaf,
          // but that is alright because asserts get
          // removed for release builds.
          assert(() {
            var leafObj = objStorage.read(leaf.hash);
            return leafObj?.formatStr() == 'blob';
          }());

          continue;
        }

        var fullPath = p.join(dir, leaf.name);
        var hash = hashMap[fullPath]!;
        assert(hash.isNotEmpty);

        entries[i] = GitTreeEntry(
          mode: leaf.mode,
          name: leaf.name,
          hash: hash,
        );
      }

      assert(entries.isNotEmpty);
      tree = GitTree.create(entries);
      treeObjects[dir] = tree;

      var hash = objStorage.writeObject(tree);
      assert(!hashMap.containsKey(dir));
      hashMap[dir] = hash;
    }

    return hashMap['']!;
  }
}

// Sort allDirs on bfs
@visibleForTesting
int dirSortFunc(String a, String b) {
  var aCnt = '/'.allMatches(a).length;
  var bCnt = '/'.allMatches(b).length;
  if (aCnt != bCnt) {
    if (aCnt < bCnt) return -1;
    if (aCnt > bCnt) return 1;
  }
  if (a.isEmpty && b.isEmpty) return 0;
  if (a.isEmpty) {
    return -1;
  }
  if (b.isEmpty) {
    return 1;
  }
  return a.compareTo(b);
}
