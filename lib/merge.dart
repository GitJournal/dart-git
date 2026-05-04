import 'package:path/path.dart' as p;
import 'package:stdlibc/stdlibc.dart' as stdlibc;

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/diff_commit.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/utils/file_extensions.dart'
    if (dart.library.html) 'package:dart_git/utils/file_extensions_na.dart';
import 'package:dart_git/utils/file_mode.dart';

extension Merge on GitRepository {
  void merge({
    required GitCommit theirCommit,
    required String message,
    required GitAuthor author,
    GitAuthor? committer,
  }) {
    committer ??= author;
    var commitB = theirCommit;

    // fetch the head commit
    var headRef = head();
    switch (headRef) {
      case HashReference():
        throw GitMergeOnHashNotAllowed();
      case SymbolicReference():
        break;
    }

    var headHash = resolveReference(headRef).hash;
    var headCommit = objStorage.readCommit(headHash);

    // up to date
    if (headHash == commitB.hash) {
      return;
    }

    var bases = mergeBase(headCommit, commitB);
    if (bases.length > 1) {
      throw GitMergeTooManyBases();
    }
    if (bases.isNotEmpty) {
      var baseHash = bases.first.hash;

      // up to date
      if (baseHash == commitB.hash) {
        return;
      }

      // fastforward
      if (baseHash == headCommit.hash) {
        var branchNameRef = headRef.target;
        assert(branchNameRef.isBranch());

        _checkoutCommitChanges(headCommit, commitB);

        var newRef = HashReference(branchNameRef, commitB.hash);
        refStorage.saveRef(newRef);
        return;
      }
    }

    var baseTree =
        bases.isNotEmpty ? objStorage.readTree(bases.first.treeHash) : null;
    var headTree = objStorage.readTree(headCommit.treeHash);
    var bTree = objStorage.readTree(commitB.treeHash);

    // TODO: Implement merge options -
    // - normal
    //   - ours
    //   - theirs
    var parents = [headHash, commitB.hash];
    var commit = GitCommit.create(
      author: author,
      committer: committer,
      parents: parents,
      message: message,
      treeHash: _combineTrees(headTree, bTree, baseTree),
    );
    objStorage.writeObject(commit);
    _checkoutCommitChanges(headCommit, commit);

    var branchNameRef = headRef.target;
    assert(branchNameRef.isBranch());
    refStorage.saveRef(HashReference(branchNameRef, commit.hash));
  }

  /// throws exceptions
  GitHash _combineTrees(GitTree a, GitTree b, GitTree? base) {
    // Get all the paths
    var names = a.entries.map((e) => e.name).toSet();
    names.addAll(b.entries.map((e) => e.name));

    var entries = <GitTreeEntry>[];
    for (var baseEntry in base?.entries ?? <GitTreeEntry>[]) {
      var name = baseEntry.name;
      var aIndex = a.entries.indexWhere((e) => e.name == name);
      var bIndex = b.entries.indexWhere((e) => e.name == name);

      var aContains = aIndex != -1;
      var bContains = bIndex != -1;

      if (!aContains && !bContains) {
        // both don't contain it!
        continue;
      } else if (aContains && !bContains) {
        var aEntry = a.entries[aIndex];
        if (aEntry.hash == baseEntry.hash && aEntry.mode == baseEntry.mode) {
          // Entry deleted in 'b' and unchanged in 'a'.
          continue;
        }

        entries.add(aEntry);
      } else if (!aContains && bContains) {
        var bEntry = b.entries[bIndex];
        if (bEntry.hash == baseEntry.hash && bEntry.mode == baseEntry.mode) {
          // Entry deleted in 'a' and unchanged in 'b'.
          continue;
        }

        entries.add(bEntry);
      } else {
        // both contain it!
        var aEntry = a.entries[aIndex];
        var bEntry = b.entries[bIndex];

        if (aEntry.hash == baseEntry.hash && aEntry.mode == baseEntry.mode) {
          entries.add(bEntry);
        } else if (bEntry.hash == baseEntry.hash &&
            bEntry.mode == baseEntry.mode) {
          entries.add(aEntry);
        } else {
          var newEntry = _resolvConflicts(aEntry, bEntry, baseEntry);
          entries.add(newEntry);
        }
      }
    }

    for (var entry in [...a.entries, ...b.entries]) {
      var name = entry.name;

      // If the entry was already in the base
      var baseIndex =
          base == null ? -1 : base.entries.indexWhere((e) => e.name == name);
      if (baseIndex != -1) {
        continue;
      }

      // If the entry was already in the merged entries
      var mergedIndex = entries.indexWhere((e) => e.name == name);
      if (mergedIndex != -1) {
        continue;
      }

      entries.add(entry);
    }

    var newTree = GitTree.create(entries);
    objStorage.writeObject(newTree);

    return newTree.hash;
  }

  GitTreeEntry _resolvConflicts(
      GitTreeEntry a, GitTreeEntry b, GitTreeEntry base) {
    if (a.hash == b.hash) {
      return a;
    }

    // Both are not Directories
    if (a.mode != GitFileMode.Dir && b.mode != GitFileMode.Dir) {
      return _resolveBlobConflict(a, b, base);
    }

    if (a.mode == GitFileMode.Dir && b.mode == GitFileMode.Dir) {
      var aTree = objStorage.readTree(a.hash);
      var bTree = objStorage.readTree(b.hash);
      var baseTree = base.mode == GitFileMode.Dir
          ? objStorage.readTree(base.hash)
          : GitTree.create();

      var newTreeHash = _combineTrees(aTree, bTree, baseTree);
      return GitTreeEntry(
        mode: GitFileMode.Dir,
        name: a.name,
        hash: newTreeHash,
      );
    }

    throw GitNotImplemented();
  }

  GitTreeEntry _resolveBlobConflict(
      GitTreeEntry a, GitTreeEntry b, GitTreeEntry base) {
    return a;
  }

  void mergeTrackingBranch({required GitAuthor author}) {
    var branch = currentBranch();
    var branchConfig = config.branch(branch);
    if (branchConfig == null) {
      throw Exception("Branch '$branch' not in config");
    }

    if (branchConfig.trackingBranch() == null) {
      throw Exception("Branch '$branch' has no tracking branch");
    }
    var remoteBranchRef = remoteBranch(
      branchConfig.remote!,
      branchConfig.trackingBranch()!,
    );

    var hash = remoteBranchRef.hash;
    var commit = objStorage.readCommit(hash);
    merge(
      theirCommit: commit,
      author: author,
      message: 'Merge ${branchConfig.remoteTrackingBranch()}',
    );

    return;
  }

  void _checkoutCommitChanges(GitCommit fromCommit, GitCommit toCommit) {
    var blobChanges = diffCommits(
      fromCommit: fromCommit,
      toCommit: toCommit,
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
        fs.file(filePath).chmodSync(to.mode.val);

        var stat = stdlibc.stat(filePath)!;
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
  }
}
