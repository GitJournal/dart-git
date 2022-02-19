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
  Result<GitCommit> commit({
    required String message,
    required GitAuthor author,
    GitAuthor? committer,
    bool addAll = false,
  }) {
    committer ??= author;

    if (addAll) {
      var r = add(workTree);
      if (r.isFailure) {
        return fail(r);
      }
    }

    var index = indexStorage.readIndex().getOrThrow();

    var treeHashR = writeTree(index);
    if (treeHashR.isFailure) {
      return fail(treeHashR);
    }
    var treeHash = treeHashR.getOrThrow();
    var parents = <GitHash>[];

    var headRefResult = head();
    if (headRefResult.isFailure) {
      if (headRefResult.error is! GitRefNotFound) {
        return fail(headRefResult);
      }
    } else {
      var headRef = headRefResult.getOrThrow();
      var parentRefResult = resolveReference(headRef);
      if (parentRefResult.isSuccess) {
        var parentRef = parentRefResult.getOrThrow();
        parents.add(parentRef.hash!);
      }
    }

    for (var parent in parents) {
      var parentCommitR = objStorage.readCommit(parent);
      if (parentCommitR.isFailure) {
        return fail(parentCommitR);
      }
      var parentCommit = parentCommitR.getOrThrow();
      if (parentCommit.treeHash == treeHash) {
        var ex = GitEmptyCommit();
        return Result.fail(ex);
      }
    }

    var commit = GitCommit.create(
      author: author,
      committer: committer,
      parents: parents,
      message: message,
      treeHash: treeHash,
    );
    var hashR = objStorage.writeObject(commit);
    if (hashR.isFailure) {
      return fail(hashR);
    }
    var hash = hashR.getOrThrow();

    // Update the ref of the current branch
    late String branchName;

    var branchNameResult = currentBranch();
    if (branchNameResult.isFailure) {
      if (branchNameResult.error is GitHeadDetached) {
        var result = head();
        if (result.isFailure) {
          return fail(result);
        }

        var h = result.getOrThrow();
        var target = h.target!;
        assert(target.isBranch());
        branchName = target.branchName()!;
      } else {
        return fail(branchNameResult);
      }
    } else {
      branchName = branchNameResult.getOrThrow();
    }

    var newRef = Reference.hash(ReferenceName.branch(branchName), hash);
    var saveRefResult = refStorage.saveRef(newRef);
    if (saveRefResult.isFailure) {
      return fail(saveRefResult);
    }

    return Result(commit);
  }

  Result<GitHash> writeTree(GitIndex index) {
    var allTreeDirs = {''};
    var treeObjects = {'': GitTree.create()};
    var treeObjFullPath = <GitTree, String>{};

    for (var entry in index.entries) {
      var fullPath = entry.path;

      var fileName = p.basename(fullPath);
      var dirName = p.dirname(fullPath);

      // Construct all the tree objects
      var allDirs = <String>[];
      while (dirName != '.') {
        var _ = allTreeDirs.add(dirName);
        allDirs.add(dirName);

        dirName = p.dirname(dirName);
      }

      allDirs.sort(dirSortFunc);

      for (var dir in allDirs) {
        if (!treeObjects.containsKey(dir)) {
          var tree = GitTree.create();
          treeObjects[dir] = tree;
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
        treeObjFullPath[parentTree] = parentDir;
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

    var allDirs = allTreeDirs.toList();
    allDirs.sort(dirSortFunc);

    for (var dir in allDirs.reversed) {
      var tree = treeObjects[dir]!;
      var entries = tree.entries.unlock;

      for (var i = 0; i < entries.length; i++) {
        var leaf = entries[i];

        if (leaf.hash.isNotEmpty) {
          //
          // Making sure the leaf is a blob
          //
          assert(() {
            var leafObjRes = objStorage.read(leaf.hash);
            var leafObj = leafObjRes.getOrThrow();
            return leafObj.formatStr() == 'blob';
          }());

          continue;
        }

        var fullPath = p.join(treeObjFullPath[tree]!, leaf.name);
        var hash = hashMap[fullPath]!;

        var d = fullPath.startsWith('test/data/diff-commits-1/.gitted/refs');
        if (d) {
          print('$fullPath -> $hash');
        }
        entries[i] = GitTreeEntry(
          mode: leaf.mode,
          name: leaf.name,
          hash: hash,
        );
      }
      treeObjects[dir] = GitTree.create(entries);

      var d = dir.startsWith('test/data/diff-commits-1/.gitted/refs');
      if (d) print('writing tree $dir ---- ${tree.hash}');
      var hashR = objStorage.writeObject(tree);
      if (hashR.isFailure) {
        return fail(hashR);
      }
      assert(!hashMap.containsKey(dir));
      hashMap[dir] = hashR.getOrThrow();
      if (d) print('x $dir -> ${hashR.getOrThrow()}');
    }

    for (var e in hashMap.entries) {
      if (!e.key.startsWith('test/data/diff-commits-1/.gitted/refs')) {
        continue;
      }
      print('h ${e.key} -> ${e.value}');
    }
    return Result(hashMap['']!);
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
