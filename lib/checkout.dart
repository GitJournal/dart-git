import 'package:path/path.dart' as p;

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/diff_commit.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/utils/result.dart';

extension Checkout on GitRepository {
  Future<int?> checkout(String path) async {
    path = normalizePath(path);

    var tree = await headTree();
    if (tree == null) {
      return null;
    }

    var spec = path.substring(workTree.length);
    var objRes = await objStorage.refSpec(tree, spec);
    var obj = objRes.get();

    if (obj is GitBlob) {
      await fs.directory(p.dirname(path)).create(recursive: true);
      await fs.file(path).writeAsBytes(obj.blobData);
      return 1;
    }

    var index = GitIndex(versionNo: 2);
    var numFiles = await _checkoutTree(spec, obj as GitTree, index);
    await indexStorage.writeIndex(index);

    return numFiles;
  }

  Future<int> _checkoutTree(
      String relativePath, GitTree tree, GitIndex index) async {
    assert(!relativePath.startsWith(p.separator));

    var dir = fs.directory(p.join(workTree, relativePath));
    await dir.create(recursive: true);

    var updated = 0;
    for (var leaf in tree.entries) {
      var obj = await objStorage.read(leaf.hash).get();
      /*
      if (obj == null) {
        // FIXME: Shout out an error, this is a problem?
        //        For now I'm silently continuing
        continue;
      }
      */

      var leafRelativePath = p.join(relativePath, leaf.name);
      if (obj is GitTree) {
        var c = await _checkoutTree(leafRelativePath, obj, index);
        updated += c;
        continue;
      }

      assert(obj is GitBlob);

      var blob = obj as GitBlob;
      var blobPath = p.join(workTree, leafRelativePath);

      await fs.directory(p.dirname(blobPath)).create(recursive: true);
      await fs.file(blobPath).writeAsBytes(blob.blobData);

      await addFileToIndex(index, blobPath);
      updated++;
    }

    return updated;
  }

  Future<Reference?> checkoutBranch(String branchName) async {
    var refRes = await refStorage.reference(ReferenceName.branch(branchName));
    if (refRes.failed || refRes.get().isSymbolic) {
      return null;
    }
    var ref = refRes.get();
    assert(ref.isHash);

    var _headCommit = await headCommit();
    if (_headCommit == null) {
      var result = await objStorage.readCommit(ref.hash!);
      var commit = result.get();
      /*
      if (obj == null) {
        return null;
      }
      */
      var treeObjRes = await objStorage.readTree(commit.treeHash);

      var index = GitIndex(versionNo: 2);
      await _checkoutTree('', treeObjRes.get(), index);
      await indexStorage.writeIndex(index);

      // Set HEAD to to it
      var branchRef = ReferenceName.branch(branchName);
      var headRef = Reference.symbolic(ReferenceName('HEAD'), branchRef);
      await refStorage.saveRef(headRef);

      return ref;
    }

    var res = await objStorage.readCommit(ref.hash!);
    var branchCommit = res.get();
    /*
    if (branchCommitObj == null) {
      return null;
    }*/

    var blobChanges = await diffCommits(
      fromCommit: _headCommit,
      toCommit: branchCommit,
      objStore: objStorage,
    );
    var index = await indexStorage.readIndex();

    for (var change in blobChanges.merged()) {
      if (change.added || change.modified) {
        var to = change.to!;
        var blobObjRes = await objStorage.readBlob(to.hash);
        var blobObj = blobObjRes.get();

        // FIXME: Add file mode
        await fs
            .directory(p.join(workTree, p.dirname(to.path)))
            .create(recursive: true);
        await fs.file(p.join(workTree, to.path)).writeAsBytes(blobObj.blobData);

        await index.updatePath(to.path, to.hash);
      } else if (change.deleted) {
        var from = change.from!;

        await fs.file(p.join(workTree, from.path)).delete(recursive: true);
        await index.removePath(from.path);
        await _deleteEmptyDirectories(workTree, from.path);
      }
    }

    await indexStorage.writeIndex(index);

    // Set HEAD to to it
    var branchRef = ReferenceName.branch(branchName);
    var headRef = Reference.symbolic(ReferenceName('HEAD'), branchRef);
    await refStorage.saveRef(headRef);

    return ref;
  }

  Future<void> _deleteEmptyDirectories(String workTree, String path) async {
    while (path != '.') {
      var dirPath = p.join(workTree, p.dirname(path));
      var dir = fs.directory(dirPath);

      var isEmpty = true;
      await for (var _ in dir.list()) {
        isEmpty = false;
        break;
      }
      if (isEmpty) {
        await dir.delete();
      }

      path = p.dirname(path);
    }
  }
}
