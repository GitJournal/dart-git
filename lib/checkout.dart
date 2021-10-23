import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/diff_commit.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/storage/object_storage_extensions.dart';
import 'package:dart_git/utils/result.dart';

import 'package:dart_git/utils/file_extensions.dart'
    if (dart.library.html) 'package:dart_git/utils/file_extensions_na.dart';

extension Checkout on GitRepository {
  /// This doesn't delete files
  Future<Result<int>> checkout(String path) => catchAll(() => _checkout(path));

  Future<Result<int>> _checkout(String path) async {
    path = normalizePath(path);

    var tree = await headTree().getOrThrow();
    var spec = path.substring(workTree.length);
    if (spec.isEmpty) {
      var index = GitIndex(versionNo: 2);
      var numFiles = await _checkoutTree(spec, tree, index).getOrThrow();
      await indexStorage.writeIndex(index).throwOnError();

      return Result(numFiles);
    }

    var treeEntry = await objStorage.refSpec(tree, spec).getOrThrow();
    var obj = await objStorage.read(treeEntry.hash).getOrThrow();

    if (obj is GitBlob) {
      var _ = await fs.directory(p.dirname(path)).create(recursive: true);
      var __ = await fs.file(path).writeAsBytes(obj.blobData);
      await fs.file(path).chmod(treeEntry.mode.val);

      return Result(1);
    }

    var index = GitIndex(versionNo: 2);
    var numFiles =
        await _checkoutTree(spec, obj as GitTree, index).getOrThrow();
    await indexStorage.writeIndex(index).throwOnError();

    return Result(numFiles);
  }

  Future<Result<int>> _checkoutTree(
    String relativePath,
    GitTree tree,
    GitIndex index,
  ) async {
    assert(!relativePath.startsWith(p.separator));

    var dir = fs.directory(p.join(workTree, relativePath));
    var _ = await dir.create(recursive: true);

    var updated = 0;
    for (var leaf in tree.entries) {
      var objR = await objStorage.read(leaf.hash);
      if (objR.isFailure) {
        return fail(objR);
      }
      var obj = objR.getOrThrow();

      var leafRelativePath = p.join(relativePath, leaf.name);
      if (obj is GitTree) {
        var res = await _checkoutTree(leafRelativePath, obj, index);
        if (res.isFailure) {
          return fail(res);
        }
        updated += res.getOrThrow();
        continue;
      }

      assert(obj is GitBlob);

      var blob = obj as GitBlob;
      var blobPath = p.join(workTree, leafRelativePath);

      var _ = await fs.directory(p.dirname(blobPath)).create(recursive: true);
      var __ = await fs.file(blobPath).writeAsBytes(blob.blobData);
      await fs.file(blobPath).chmod(leaf.mode.val);

      var res = await addFileToIndex(index, blobPath);
      if (res.isFailure) {
        return fail(res);
      }
      updated++;
    }

    return Result(updated);
  }

  Future<Result<Reference>> checkoutBranch(String branchName) async =>
      catchAll(() => _checkoutBranch(branchName));

  Future<Result<Reference>> _checkoutBranch(String branchName) async {
    var ref = await refStorage
        .reference(ReferenceName.branch(branchName))
        .getOrThrow();
    assert(ref.isHash);

    var headCommitR = await headCommit();
    if (headCommitR.isFailure) {
      if (headCommitR.error is! GitRefNotFound) {
        return fail(headCommitR);
      }

      var commit = await objStorage.readCommit(ref.hash!).getOrThrow();
      var treeObj = await objStorage.readTree(commit.treeHash).getOrThrow();

      var index = GitIndex(versionNo: 2);
      await _checkoutTree('', treeObj, index).throwOnError();
      await indexStorage.writeIndex(index).throwOnError();

      // Set HEAD to to it
      var branchRef = ReferenceName.branch(branchName);
      var headRef = Reference.symbolic(ReferenceName('HEAD'), branchRef);
      await refStorage.saveRef(headRef).throwOnError();

      return Result(ref);
    }
    var _headCommit = headCommitR.getOrThrow();

    var branchCommit = await objStorage.readCommit(ref.hash!).getOrThrow();

    var blobChanges = await diffCommits(
      fromCommit: _headCommit,
      toCommit: branchCommit,
      objStore: objStorage,
    ).getOrThrow();
    var index = await indexStorage.readIndex().getOrThrow();

    for (var change in blobChanges.merged()) {
      if (change.add || change.modify) {
        var to = change.to!;
        var blobObj = await objStorage.readBlob(to.hash).getOrThrow();

        var _ = await fs
            .directory(p.join(workTree, p.dirname(to.path)))
            .create(recursive: true);

        var filePath = p.join(workTree, to.path);
        var __ = await fs.file(filePath).writeAsBytes(blobObj.blobData);
        await fs.file(filePath).chmod(change.to!.mode.val);

        await index.updatePath(to.path, to.hash);
      } else if (change.delete) {
        var from = change.from!;

        var _ =
            await fs.file(p.join(workTree, from.path)).delete(recursive: true);
        var __ = index.removePath(from.path);
        await deleteEmptyDirectories(fs, workTree, from.path);
      }
    }

    await indexStorage.writeIndex(index).throwOnError();

    // Set HEAD to to it
    var branchRef = ReferenceName.branch(branchName);
    var headRef = Reference.symbolic(ReferenceName('HEAD'), branchRef);
    await refStorage.saveRef(headRef).throwOnError();

    return Result(ref);
  }
}

Future<void> deleteEmptyDirectories(
    FileSystem fs, String workTree, String path) async {
  while (path != '.') {
    var dirPath = p.join(workTree, p.dirname(path));
    var dir = fs.directory(dirPath);

    var isEmpty = true;
    await for (var _ in dir.list()) {
      isEmpty = false;
      break;
    }
    if (isEmpty) {
      var _ = await dir.delete();
    }

    path = p.dirname(path);
  }
}
