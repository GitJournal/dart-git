import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/diff_commit.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';

import 'package:dart_git/utils/file_extensions.dart'
    if (dart.library.html) 'package:dart_git/utils/file_extensions_na.dart';

extension Checkout on GitRepository {
  /// This doesn't delete files
  Result<int> checkout(String path) => catchAllSync(() => _checkout(path));

  Result<int> _checkout(String path) {
    path = normalizePath(path);

    var tree = headTree().getOrThrow();
    var spec = path.substring(workTree.length);
    if (spec.isEmpty) {
      var index = GitIndex(versionNo: 2);
      var numFiles = _checkoutTree(spec, tree, index).getOrThrow();
      indexStorage.writeIndex(index).throwOnError();

      return Result(numFiles);
    }

    var treeEntry = objStorage.refSpec(tree, spec).getOrThrow();
    var obj = objStorage.read(treeEntry.hash).getOrThrow();

    if (obj is GitBlob) {
      fs.directory(p.dirname(path)).createSync(recursive: true);
      fs.file(path).writeAsBytesSync(obj.blobData);
      fs.file(path).chmodSync(treeEntry.mode.val);

      return Result(1);
    }

    var index = GitIndex(versionNo: 2);
    var numFiles = _checkoutTree(spec, obj as GitTree, index).getOrThrow();
    indexStorage.writeIndex(index).throwOnError();

    return Result(numFiles);
  }

  Result<int> _checkoutTree(
    String relativePath,
    GitTree tree,
    GitIndex index,
  ) {
    assert(!relativePath.startsWith(p.separator));

    var dir = fs.directory(p.join(workTree, relativePath));
    dir.createSync(recursive: true);

    var updated = 0;
    for (var leaf in tree.entries) {
      var objR = objStorage.read(leaf.hash);
      if (objR.isFailure) {
        return fail(objR);
      }
      var obj = objR.getOrThrow();

      var leafRelativePath = p.join(relativePath, leaf.name);
      if (obj is GitTree) {
        var res = _checkoutTree(leafRelativePath, obj, index);
        if (res.isFailure) {
          return fail(res);
        }
        updated += res.getOrThrow();
        continue;
      }

      assert(obj is GitBlob);

      var blob = obj as GitBlob;
      var blobPath = p.join(workTree, leafRelativePath);

      fs.directory(p.dirname(blobPath)).createSync(recursive: true);
      fs.file(blobPath).writeAsBytesSync(blob.blobData);
      fs.file(blobPath).chmodSync(leaf.mode.val);

      var res = addFileToIndex(index, blobPath);
      if (res.isFailure) {
        return fail(res);
      }
      updated++;
    }

    return Result(updated);
  }

  Result<Reference> checkoutBranch(String branchName) =>
      catchAllSync(() => _checkoutBranch(branchName));

  Result<Reference> _checkoutBranch(String branchName) {
    var ref =
        refStorage.reference(ReferenceName.branch(branchName)).getOrThrow();
    assert(ref.isHash);

    var headCommitR = headCommit();
    if (headCommitR.isFailure) {
      if (headCommitR.error is! GitRefNotFound) {
        return fail(headCommitR);
      }

      var commit = objStorage.readCommit(ref.hash!).getOrThrow();
      var treeObj = objStorage.readTree(commit.treeHash).getOrThrow();

      var index = GitIndex(versionNo: 2);
      _checkoutTree('', treeObj, index).throwOnError();
      indexStorage.writeIndex(index).throwOnError();

      // Set HEAD to to it
      var branchRef = ReferenceName.branch(branchName);
      var headRef = Reference.symbolic(ReferenceName.HEAD(), branchRef);
      refStorage.saveRef(headRef).throwOnError();

      return Result(ref);
    }
    var _headCommit = headCommitR.getOrThrow();

    var branchCommit = objStorage.readCommit(ref.hash!).getOrThrow();

    var blobChanges = diffCommits(
      fromCommit: _headCommit,
      toCommit: branchCommit,
      objStore: objStorage,
    ).getOrThrow();
    var index = indexStorage.readIndex().getOrThrow();

    for (var change in blobChanges.merged()) {
      if (change.add || change.modify) {
        var to = change.to!;
        var blobObj = objStorage.readBlob(to.hash).getOrThrow();

        var _ = fs
            .directory(p.join(workTree, p.dirname(to.path)))
            .createSync(recursive: true);

        var filePath = p.join(workTree, to.path);
        fs.file(filePath).writeAsBytesSync(blobObj.blobData);
        fs.file(filePath).chmodSync(change.to!.mode.val);

        index.updatePath(to.path, to.hash);
      } else if (change.delete) {
        var from = change.from!;

        fs.file(p.join(workTree, from.path)).deleteSync(recursive: true);
        var _ = index.removePath(from.path);
        deleteEmptyDirectories(fs, workTree, from.path);
      }
    }

    indexStorage.writeIndex(index).throwOnError();

    // Set HEAD to to it
    var branchRef = ReferenceName.branch(branchName);
    var headRef = Reference.symbolic(ReferenceName.HEAD(), branchRef);
    refStorage.saveRef(headRef).throwOnError();

    return Result(ref);
  }
}

void deleteEmptyDirectories(FileSystem fs, String workTree, String path) {
  while (path != '.') {
    var dirPath = p.join(workTree, p.dirname(path));
    var dir = fs.directory(dirPath);

    var isEmpty = true;
    for (var _ in dir.listSync()) {
      isEmpty = false;
      break;
    }
    if (isEmpty) {
      var _ = dir.deleteSync();
    }

    path = p.dirname(path);
  }
}
