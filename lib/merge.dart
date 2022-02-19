import 'package:dart_git/dart_git.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/utils/file_mode.dart';

extension Merge on GitRepository {
  Result<void> merge({
    required GitCommit theirCommit,
    required String message,
    required GitAuthor author,
    GitAuthor? committer,
  }) {
    committer ??= author;
    var commitB = theirCommit;

    // fetch the head commit
    var headR = head();
    if (headR.isFailure) {
      return fail(headR);
    }
    var headRef = headR.getOrThrow();

    if (headRef.isHash) {
      var ex = GitMergeOnHashNotAllowed();
      return Result.fail(ex);
    }

    var headHashRefR = resolveReference(headRef);
    if (headHashRefR.isFailure) {
      return fail(headHashRefR);
    }
    var headHash = headHashRefR.getOrThrow().hash!;

    var headCommitR = objStorage.readCommit(headHash);
    if (headCommitR.isFailure) {
      return fail(headCommitR);
    }
    var headCommit = headCommitR.getOrThrow();

    // up to date
    if (headHash == commitB.hash) {
      return Result(null);
    }

    var baseR = mergeBase(headCommit, commitB);
    if (baseR.isFailure) {
      return fail(baseR);
    }
    var bases = baseR.getOrThrow();

    if (bases.length > 1) {
      var ex = GitMergeTooManyBases();
      return Result.fail(ex);
    }
    if (bases.isNotEmpty) {
      var baseHash = bases.first.hash;

      // up to date
      if (baseHash == commitB.hash) {
        return Result(null);
      }

      // fastforward
      if (baseHash == headCommit.hash) {
        var branchNameRef = headRef.target!;
        assert(branchNameRef.isBranch());

        var newRef = Reference.hash(branchNameRef, commitB.hash);
        var saveRefResult = refStorage.saveRef(newRef);
        if (saveRefResult.isFailure) {
          return fail(saveRefResult);
        }

        var res = checkout('.');
        if (res.isFailure) {
          return fail(res);
        }

        return Result(null);
      }
    }

    var headTree = objStorage.readTree(headCommit.treeHash).getOrThrow();
    var bTree = objStorage.readTree(commitB.treeHash).getOrThrow();

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
      treeHash: _combineTrees(headTree, bTree).getOrThrow(),
    );
    var r = objStorage.writeObject(commit);
    if (r.isFailure) {
      return fail(r);
    }
    return resetHard(commit.hash);

    // - unborn ?

    // Full 3 way
    // https://stackoverflow.com/questions/4129049/why-is-a-3-way-merge-advantageous-over-a-2-way-merge
  }

  /// throws exceptions
  Result<GitHash> _combineTrees(GitTree a, GitTree b) {
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
          var aEntryTree = objStorage.readTree(aEntry.hash).getOrThrow();
          var bEntryTree = objStorage.readTree(bEntry.hash).getOrThrow();

          var newTreeHash = _combineTrees(
            aEntryTree,
            bEntryTree,
          ).getOrThrow();

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
    var r = objStorage.writeObject(newTree);
    if (r.isFailure) {
      return fail(r);
    }

    return Result(newTree.hash);
  }

  // Convenience method
  Result<void> mergeCurrentTrackingBranch({
    required GitAuthor author,
  }) =>
      catchAllSync(() => _mergeTrackingBranch(author: author));

  Result<void> _mergeTrackingBranch({required GitAuthor author}) {
    var branch = currentBranch().getOrThrow();
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
    ).getOrThrow();

    var hash = remoteBranchRef.hash!;
    var commit = objStorage.readCommit(hash).getOrThrow();
    merge(
      theirCommit: commit,
      author: author,
      message: 'Merge ${branchConfig.remoteTrackingBranch()}',
    ).throwOnError();

    return Result(null);
  }
}
