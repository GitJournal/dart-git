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
  int checkout(String path) {
    path = normalizePath(path);

    var tree = headTree();
    var spec = path.substring(workTree.length);
    if (spec.isEmpty) {
      var index = GitIndex(versionNo: 2);
      var numFiles = _checkoutTree(spec, tree, index);
      indexStorage.writeIndex(index);

      return numFiles;
    }

    var treeEntry = objStorage.refSpec(tree, spec);
    var obj = objStorage.read(treeEntry.hash);

    if (obj is GitBlob) {
      fs.directory(p.dirname(path)).createSync(recursive: true);
      fs.file(path).writeAsBytesSync(obj.blobData);
      fs.file(path).chmodSync(treeEntry.mode.val);

      return 1;
    }

    var index = GitIndex(versionNo: 2);
    var numFiles = _checkoutTree(spec, obj as GitTree, index);
    indexStorage.writeIndex(index);

    return numFiles;
  }

  int _checkoutTree(
    String relativePath,
    GitTree tree,
    GitIndex index,
  ) {
    assert(!relativePath.startsWith(p.separator));

    var dir = fs.directory(p.join(workTree, relativePath));
    dir.createSync(recursive: true);

    var updated = 0;
    for (var leaf in tree.entries) {
      var obj = objStorage.read(leaf.hash);

      var leafRelativePath = p.join(relativePath, leaf.name);
      if (obj is GitTree) {
        var res = _checkoutTree(leafRelativePath, obj, index);
        updated += res;
        continue;
      }

      assert(obj is GitBlob);

      var blob = obj as GitBlob;
      var blobPath = p.join(workTree, leafRelativePath);

      fs.directory(p.dirname(blobPath)).createSync(recursive: true);
      fs.file(blobPath).writeAsBytesSync(blob.blobData);
      fs.file(blobPath).chmodSync(leaf.mode.val);

      addFileToIndex(index, blobPath);
      updated++;
    }

    return updated;
  }

  HashReference checkoutBranch(String branchName) {
    var branchRef = ReferenceName.branch(branchName);
    var ref = refStorage.reference(branchRef);
    if (ref == null) {
      throw GitRefNotFound(branchRef);
    }
    if (ref is! HashReference) {
      throw GitRefNotHash(branchRef);
    }

    late GitCommit _headCommit;
    try {
      _headCommit = headCommit();
    } on GitRefNotFound {
      var commit = objStorage.readCommit(ref.hash);
      var treeObj = objStorage.readTree(commit.treeHash);

      var index = GitIndex(versionNo: 2);
      _checkoutTree('', treeObj, index);
      indexStorage.writeIndex(index);

      // Set HEAD to to it
      var headRef = SymbolicReference(ReferenceName.HEAD(), branchRef);
      refStorage.saveRef(headRef);

      return ref;
    }

    var branchCommit = objStorage.readCommit(ref.hash);

    var blobChanges = diffCommits(
      fromCommit: _headCommit,
      toCommit: branchCommit,
      objStore: objStorage,
    );
    var index = indexStorage.readIndex();

    for (var change in blobChanges.merged()) {
      if (change.add || change.modify) {
        var to = change.to!;
        var blobObj = objStorage.readBlob(to.hash);

        fs
            .directory(p.join(workTree, p.dirname(to.path)))
            .createSync(recursive: true);

        var filePath = p.join(workTree, to.path);
        fs.file(filePath).writeAsBytesSync(blobObj.blobData);
        fs.file(filePath).chmodSync(change.to!.mode.val);

        var stat = fs.file(filePath).statSync();
        index.updatePath(to.path, to.hash, stat);
      } else if (change.delete) {
        var from = change.from!;

        var file = fs.file(p.join(workTree, from.path));
        if (file.existsSync()) {
          file.deleteSync(recursive: true);
        }
        index.removePath(from.path);
        deleteEmptyDirectories(fs, workTree, from.path);
      }
    }

    indexStorage.writeIndex(index);

    // Set HEAD to to it
    var headRef = SymbolicReference(ReferenceName.HEAD(), branchRef);
    refStorage.saveRef(headRef);

    return ref;
  }
}

void deleteEmptyDirectories(FileSystem fs, String workTree, String path) {
  while (path != '.') {
    var dirPath = p.join(workTree, p.dirname(path));
    var dir = fs.directory(dirPath);
    if (!dir.existsSync()) {
      break;
    }

    var isEmpty = true;
    for (var _ in dir.listSync()) {
      isEmpty = false;
      break;
    }
    if (isEmpty) {
      dir.deleteSync();
    }

    path = p.dirname(path);
  }
}
