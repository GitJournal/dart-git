import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/utils/file_mode.dart';

extension Commit on GitRepository {
  Future<Result<GitCommit>> commit({
    required String message,
    required GitAuthor author,
    GitAuthor? committer,
    bool addAll = false,
  }) async {
    committer ??= author;

    if (addAll) {
      await add(workTree);
    }

    var index = await indexStorage.readIndex().get();

    var treeHashR = await writeTree(index);
    if (treeHashR.failed) {
      return fail(treeHashR);
    }
    var treeHash = treeHashR.get();
    // FIXME: Check if empty commits are still not allowed!
    /*
    if (treeHash == null) {
      throw Exception('WTF, there is nothing to add?');
    }
    */
    var parents = <GitHash>[];

    var headRefResult = await head();
    if (headRefResult.failed) {
      if (headRefResult.error is! GitRefNotFound) {
        return fail(headRefResult);
      }
    } else {
      var headRef = headRefResult.get();
      var parentRefResult = await resolveReference(headRef);
      if (parentRefResult.succeeded) {
        var parentRef = parentRefResult.get();
        parents.add(parentRef.hash!);
      }
    }

    var commit = GitCommit.create(
      author: author,
      committer: committer,
      parents: parents,
      message: message,
      treeHash: treeHash,
    );
    var hashR = await objStorage.writeObject(commit);
    if (hashR.failed) {
      return fail(hashR);
    }
    var hash = hashR.get();

    // Update the ref of the current branch
    late String branchName;

    var branchNameResult = await currentBranch();
    if (branchNameResult.failed) {
      if (branchNameResult.error is GitHeadDetached) {
        var result = await head();
        if (result.failed) {
          return fail(result);
        }

        var h = result.get();
        var target = h.target!;
        assert(target.isBranch());
        branchName = target.branchName()!;
      } else {
        return fail(branchNameResult);
      }
    } else {
      branchName = branchNameResult.get();
    }

    var newRef = Reference.hash(ReferenceName.branch(branchName), hash);
    var saveRefResult = await refStorage.saveRef(newRef);
    if (saveRefResult.failed) {
      return fail(saveRefResult);
    }

    return Result(commit);
  }

  Future<Result<GitHash>> writeTree(GitIndex index) async {
    var allTreeDirs = {''};
    var treeObjects = {'': GitTree.empty()};
    var treeObjFullPath = <GitTree, String>{};

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
          var tree = GitTree.empty();
          treeObjects[dir] = tree;
        }

        var parentDir = p.dirname(dir);
        if (parentDir == '.') parentDir = '';

        var parentTree = treeObjects[parentDir]!;
        var folderName = p.basename(dir);
        treeObjFullPath[parentTree] = parentDir;

        var i = parentTree.entries.indexWhere((e) => e.name == folderName);
        if (i != -1) {
          continue;
        }
        parentTree.entries.add(GitTreeEntry(
          mode: GitFileMode.Dir,
          name: folderName,
          hash: GitHash.zero(),
        ));
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
      treeObjects[dirName]!.entries.add(leaf);
    }
    assert(treeObjects.containsKey(''));

    // Write all the tree objects
    var hashMap = <String, GitHash>{};

    var allDirs = allTreeDirs.toList();
    allDirs.sort(dirSortFunc);

    for (var dir in allDirs.reversed) {
      var tree = treeObjects[dir]!;

      for (var i = 0; i < tree.entries.length; i++) {
        var leaf = tree.entries[i];

        if (leaf.hash.isNotEmpty) {
          //
          // Making sure the leaf is a blob
          //
          assert(await () async {
            var leafObjRes = await objStorage.read(leaf.hash);
            var leafObj = leafObjRes.get();
            return leafObj.formatStr() == 'blob';
          }());

          continue;
        }

        var fullPath = p.join(treeObjFullPath[tree]!, leaf.name);
        var hash = hashMap[fullPath]!;

        tree.entries[i] = GitTreeEntry(
          mode: leaf.mode,
          name: leaf.name,
          hash: hash,
        );
      }

      var hashR = await objStorage.writeObject(tree);
      if (hashR.failed) {
        return fail(hashR);
      }
      hashMap[dir] = hashR.get();
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
