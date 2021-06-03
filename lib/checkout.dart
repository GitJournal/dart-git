import 'package:path/path.dart' as p;

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/diff_commit.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/utils/result.dart';

extension Checkout on GitRepository {
  Future<Result<int>> checkout(String path) async {
    path = normalizePath(path);

    try {
      var tree = await headTree().get();
      var spec = path.substring(workTree.length);
      var obj = await objStorage.refSpec(tree, spec).get();

      if (obj is GitBlob) {
        await fs.directory(p.dirname(path)).create(recursive: true);
        await fs.file(path).writeAsBytes(obj.blobData);
        return Result(1);
      }

      var index = GitIndex(versionNo: 2);
      var numFiles = await _checkoutTree(spec, obj as GitTree, index).get();
      var result = await indexStorage.writeIndex(index);
      if (result.isFailure) {
        return fail(result);
      }

      return Result(numFiles);
    } catch (ex) {
      return Result.fail(ex as Exception);
    }
  }

  Future<Result<int>> _checkoutTree(
    String relativePath,
    GitTree tree,
    GitIndex index,
  ) async {
    assert(!relativePath.startsWith(p.separator));

    var dir = fs.directory(p.join(workTree, relativePath));
    await dir.create(recursive: true);

    var updated = 0;
    for (var leaf in tree.entries) {
      var objR = await objStorage.read(leaf.hash);
      if (objR.isFailure) {
        return fail(objR);
      }
      var obj = objR.get();

      var leafRelativePath = p.join(relativePath, leaf.name);
      if (obj is GitTree) {
        var res = await _checkoutTree(leafRelativePath, obj, index);
        if (res.isFailure) {
          return fail(res);
        }
        updated += res.get();
        continue;
      }

      assert(obj is GitBlob);

      var blob = obj as GitBlob;
      var blobPath = p.join(workTree, leafRelativePath);

      await fs.directory(p.dirname(blobPath)).create(recursive: true);
      await fs.file(blobPath).writeAsBytes(blob.blobData);

      var res = await addFileToIndex(index, blobPath);
      if (res.isFailure) {
        return fail(res);
      }
      updated++;
    }

    return Result(updated);
  }

  Future<Result<Reference>> checkoutBranch(String branchName) async {
    var refRes = await refStorage.reference(ReferenceName.branch(branchName));
    if (refRes.isFailure) {
      return fail(refRes);
    }
    var ref = refRes.get();
    assert(ref.isHash);

    var headCommitR = await headCommit();
    if (headCommitR.isFailure) {
      if (headCommitR.error is! GitRefNotFound) {
        return fail(headCommitR);
      }

      var commitR = await objStorage.readCommit(ref.hash!);
      if (commitR.isFailure) {
        return fail(commitR);
      }
      var commit = commitR.get();

      var treeObjRes = await objStorage.readTree(commit.treeHash);
      if (treeObjRes.isFailure) {
        return fail(treeObjRes);
      }
      var treeObj = treeObjRes.get();

      var index = GitIndex(versionNo: 2);
      var checkoutR = await _checkoutTree('', treeObj, index);
      if (checkoutR.isFailure) {
        return fail(checkoutR);
      }

      var writeR = await indexStorage.writeIndex(index);
      if (writeR.isFailure) {
        return fail(writeR);
      }

      // Set HEAD to to it
      var branchRef = ReferenceName.branch(branchName);
      var headRef = Reference.symbolic(ReferenceName('HEAD'), branchRef);
      var saveRefR = await refStorage.saveRef(headRef);
      if (saveRefR.isFailure) {
        return fail(saveRefR);
      }

      return Result(ref);
    }
    var _headCommit = headCommitR.get();

    var res = await objStorage.readCommit(ref.hash!);
    if (res.isFailure) {
      return fail(res);
    }
    var branchCommit = res.get();

    var blobChanges = await diffCommits(
      fromCommit: _headCommit,
      toCommit: branchCommit,
      objStore: objStorage,
    );
    var indexR = await indexStorage.readIndex();
    if (indexR.isFailure) {
      return fail(indexR);
    }
    var index = indexR.get();

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
        index.removePath(from.path);
        await _deleteEmptyDirectories(workTree, from.path);
      }
    }

    var writeR = await indexStorage.writeIndex(index);
    if (writeR.isFailure) {
      return fail(writeR);
    }

    // Set HEAD to to it
    var branchRef = ReferenceName.branch(branchName);
    var headRef = Reference.symbolic(ReferenceName('HEAD'), branchRef);

    var saveRefR = await refStorage.saveRef(headRef);
    if (saveRefR.isFailure) {
      return fail(saveRefR);
    }

    return Result(ref);
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
