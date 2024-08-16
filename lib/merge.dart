import 'package:dart_git/dart_git.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';
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

        var newRef = HashReference(branchNameRef, commitB.hash);
        refStorage.saveRef(newRef);

        checkout('.');
        return;
      }
    }

    var baseTree = objStorage.readTree(bases.first.treeHash);
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
    return resetHard(commit.hash);
  }

  /// throws exceptions
  GitHash _combineTrees(GitTree a, GitTree b, GitTree base) {
    // Get all the paths
    var names = a.entries.map((e) => e.name).toSet();
    names.addAll(b.entries.map((e) => e.name));

    var entries = <GitTreeEntry>[];
    for (var baseEntry in base.entries) {
      var name = baseEntry.name;
      var aIndex = a.entries.indexWhere((e) => e.name == name);
      var bIndex = b.entries.indexWhere((e) => e.name == name);

      var aContains = aIndex != -1;
      var bContains = bIndex != -1;

      if (!aContains && !bContains) {
        // both don't contain it!
        continue;
      } else if (aContains && !bContains) {
        // Entry deleted in 'b', but exists in 'a'
        // Delete this entry in the merged result
        continue;
      } else if (!aContains && bContains) {
        // Entry deleted in 'a', but exists in 'b'
        var bEntry = b.entries[bIndex];
        entries.add(bEntry);
      } else {
        // both contain it!
        var aEntry = a.entries[aIndex];
        var bEntry = b.entries[bIndex];

        var newEntry = _resolvConflicts(aEntry, bEntry, baseEntry);
        entries.add(newEntry);
      }
    }

    for (var entry in [...a.entries, ...b.entries]) {
      var name = entry.name;

      // If the entry was already in the base
      var baseIndex = base.entries.indexWhere((e) => e.name == name);
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
}
