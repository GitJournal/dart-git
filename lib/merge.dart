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
      treeHash: _combineTrees(headTree, bTree),
    );
    objStorage.writeObject(commit);
    return resetHard(commit.hash);

    // - unborn ?

    // Full 3 way
    // https://stackoverflow.com/questions/4129049/why-is-a-3-way-merge-advantageous-over-a-2-way-merge
  }

  /// throws exceptions
  GitHash _combineTrees(GitTree a, GitTree b) {
    // Get all the paths
    var names = a.entries.map((e) => e.name).toSet();
    names.addAll(b.entries.map((e) => e.name));

    var entries = <GitTreeEntry>[];
    for (var name in names) {
      var aIndex = a.entries.indexWhere((e) => e.name == name);
      var bIndex = b.entries.indexWhere((e) => e.name == name);

      var aContains = aIndex != -1;
      var bContains = bIndex != -1;

      if (aContains && !bContains) {
        var aEntry = a.entries[aIndex];
        entries.add(aEntry);
      } else if (!aContains && bContains) {
        var bEntry = b.entries[bIndex];
        entries.add(bEntry);
      } else {
        // both contain it!
        var aEntry = a.entries[aIndex];
        var bEntry = b.entries[bIndex];

        if (aEntry.mode == GitFileMode.Dir && bEntry.mode == GitFileMode.Dir) {
          var aEntryTree = objStorage.readTree(aEntry.hash);
          var bEntryTree = objStorage.readTree(bEntry.hash);

          var newTreeHash = _combineTrees(
            aEntryTree,
            bEntryTree,
          );

          var entry = GitTreeEntry(
            mode: GitFileMode.Dir,
            name: aEntry.name,
            hash: newTreeHash,
          );
          entries.add(entry);
          continue;
        } else if (aEntry.mode != GitFileMode.Dir &&
            bEntry.mode != GitFileMode.Dir) {
          // FIXME: Which one to pick?
          var aEntry = a.entries[aIndex];
          entries.add(aEntry);
          continue;
        }

        throw GitNotImplemented();
      }
    }

    var newTree = GitTree.create(entries);
    objStorage.writeObject(newTree);

    return newTree.hash;
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
