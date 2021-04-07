// @dart=2.9

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/diff_commit.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:path/path.dart' as p;

extension Checkout on GitRepository {
  Future<int> checkout(String path) async {
    path = _normalizePath(path);

    var tree = await headTree();

    var spec = path.substring(workTree.length);
    var obj = await objStorage.refSpec(tree, spec);
    if (obj == null) {
      return null;
    }

    if (obj is GitBlob) {
      await fs.directory(p.dirname(path)).create(recursive: true);
      await fs.file(path).writeAsBytes(obj.blobData);
      return 1;
    }

    var index = GitIndex(versionNo: 2);
    var numFiles = await _checkoutTree(spec, obj as GitTree, index);
    await writeIndex(index);

    return numFiles;
  }

  Future<int> _checkoutTree(
      String relativePath, GitTree tree, GitIndex index) async {
    assert(!relativePath.startsWith(p.separator));

    var dir = fs.directory(p.join(workTree, relativePath));
    await dir.create(recursive: true);

    var updated = 0;
    for (var leaf in tree.entries) {
      var obj = await objStorage.readObjectFromHash(leaf.hash);
      assert(obj != null);

      var leafRelativePath = p.join(relativePath, leaf.name);
      if (obj is GitTree) {
        await _checkoutTree(leafRelativePath, obj, index);
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

  Future<Reference> checkoutBranch(String branchName) async {
    var ref = await refStorage.reference(ReferenceName.branch(branchName));
    if (ref == null) {
      return null;
    }
    assert(ref.isHash);

    var _headCommit = await headCommit();

    if (_headCommit == null) {
      var obj = await objStorage.readObjectFromHash(ref.hash);
      var commit = obj as GitCommit;
      var treeObj = await objStorage.readObjectFromHash(commit.treeHash);

      var index = GitIndex(versionNo: 2);
      await _checkoutTree('', treeObj, index);
      await writeIndex(index);

      // Set HEAD to to it
      var branchRef = ReferenceName.branch(branchName);
      var headRef = Reference.symbolic(ReferenceName('HEAD'), branchRef);
      await refStorage.saveRef(headRef);

      return ref;
    }

    var branchCommit =
        await objStorage.readObjectFromHash(ref.hash) as GitCommit;

    var blobChanges = await diffCommits(
      fromCommit: _headCommit,
      toCommit: branchCommit,
      objStore: objStorage,
    );
    var index = await readIndex();

    for (var change in blobChanges.merged()) {
      if (change.added || change.modified) {
        var obj = await objStorage.readObjectFromHash(change.to.hash);
        var blobObj = obj as GitBlob;

        // FIXME: Add file mode
        await fs
            .directory(p.join(workTree, p.dirname(change.path)))
            .create(recursive: true);
        await fs
            .file(p.join(workTree, change.path))
            .writeAsBytes(blobObj.blobData);

        await index.updatePath(change.to.path, change.to.hash);
      } else if (change.deleted) {
        await fs
            .file(p.join(workTree, change.from.path))
            .delete(recursive: true);

        // FIXME: What if the parent directory also needs to be removed?
        var dir = fs.directory(p.join(workTree, p.dirname(change.from.path)));
        await index.removePath(change.from.path);

        var isEmpty = true;
        await for (var _ in dir.list()) {
          isEmpty = false;
          break;
        }
        if (isEmpty) {
          await dir.delete();
        }
      }
    }

    await writeIndex(index);

    // Set HEAD to to it
    var branchRef = ReferenceName.branch(branchName);
    var headRef = Reference.symbolic(ReferenceName('HEAD'), branchRef);
    await refStorage.saveRef(headRef);

    return ref;
  }

  String _normalizePath(String path) {
    if (!path.startsWith('/')) {
      path = path == '.' ? workTree : p.normalize(p.join(workTree, path));
    }
    if (!path.startsWith(workTree)) {
      throw PathSpecOutsideRepoException(pathSpec: path);
    }
    return path;
  }
}
