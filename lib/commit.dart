import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/utils/file_mode.dart';

extension Commit on GitRepository {
  Future<GitCommit> commit({
    required String message,
    required GitAuthor author,
    GitAuthor? committer,
    bool addAll = false,
  }) async {
    committer ??= author;

    var index = await readIndex();

    if (addAll) {
      await addDirectoryToIndex(index, workTree, recursive: true);
      await writeIndex(index);
    }

    var treeHash = await writeTree(index);
    if (treeHash == null) {
      throw Exception('WTF, there is nothing to add?');
    }
    var parents = <GitHash?>[];

    var headRef = await head();
    if (headRef != null) {
      var parentRef = await resolveReference(headRef);
      if (parentRef != null) {
        parents.add(parentRef.hash);
      }
    }

    var commit = GitCommit.create(
      author: author,
      committer: committer,
      parents: parents as List<GitHash>,
      message: message,
      treeHash: treeHash,
    );
    var hash = await objStorage.writeObject(commit);

    // Update the ref of the current branch
    var branchName = await currentBranch();
    if (branchName == null) {
      var h = await head();
      if (h == null) {
        throw Exception('Could not update current branch');
      }
      var target = h.target!;
      assert(target.isBranch());
      branchName = target.branchName();
    }

    var newRef = Reference.hash(ReferenceName.branch(branchName!), hash);

    await refStorage.saveRef(newRef);

    return commit;
  }

  Future<GitHash?> writeTree(GitIndex index) async {
    var allTreeDirs = {''};
    var treeObjects = {'': GitTree.empty()};
    var treeObjFullPath = <GitTree, String>{};

    index.entries.forEach((entry) {
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
    });
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
            var leafObj = await objStorage.readObjectFromHash(leaf.hash);
            if (leafObj == null) {
              return false;
            }
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

      var hash = await objStorage.writeObject(tree);
      hashMap[dir] = hash;
    }

    return hashMap[''];
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
