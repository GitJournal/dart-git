import 'package:dart_git/dart_git.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/utils/file_mode.dart';

extension Merge on GitRepository {
  Future<Result<void>> merge({
    required GitCommit theirCommit,
    required String message,
    required GitAuthor author,
    GitAuthor? committer,
  }) async {
    committer ??= author;
    var commitB = theirCommit;

    // fetch the head commit
    var headR = await head();
    if (headR.isFailure) {
      return fail(headR);
    }
    var headRef = headR.getOrThrow();

    if (headRef.isHash) {
      var ex = GitMergeOnHashNotAllowed();
      return Result.fail(ex);
    }

    var headHashRefR = await resolveReference(headRef);
    if (headHashRefR.isFailure) {
      return fail(headHashRefR);
    }
    var headHash = headHashRefR.getOrThrow().hash!;

    var headCommitR = await objStorage.read(headHash);
    if (headCommitR.isFailure) {
      return fail(headCommitR);
    }
    var headCommit = headCommitR.getOrThrow() as GitCommit;

    // up to date
    if (headHash == commitB.hash) {
      return Result(null);
    }

    var baseR = await mergeBase(headCommit, commitB);
    if (baseR.isFailure) {
      return fail(baseR);
    }
    var bases = baseR.getOrThrow();

    if (bases.length > 1) {
      var ex = GitMergeTooManyBases();
      return Result.fail(ex);
    }
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
      var saveRefResult = await refStorage.saveRef(newRef);
      if (saveRefResult.isFailure) {
        return fail(saveRefResult);
      }

      var res = await checkout('.');
      if (res.isFailure) {
        return fail(res);
      }

      return Result(null);
    }

    var headTree = await objStorage.read(headCommit.treeHash).getOrThrow();
    var bTree = await objStorage.read(commitB.treeHash).getOrThrow();

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
      treeHash: await _combineTrees(
        headTree as GitTree,
        bTree as GitTree,
      ).getOrThrow(),
    );
    var hashR = await objStorage.writeObject(commit);
    if (hashR.isFailure) {
      return fail(hashR);
    }
    var mergeCommitHash = hashR.getOrThrow();
    print(mergeCommitHash);
    return resetHard(mergeCommitHash);

    // - unborn ?

    // Full 3 way
    // https://stackoverflow.com/questions/4129049/why-is-a-3-way-merge-advantageous-over-a-2-way-merge
  }

  /// throws exceptions
  Future<Result<GitHash>> _combineTrees(GitTree a, GitTree b) async {
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
          var aEntryTree = await objStorage.read(aEntry.hash).getOrThrow();
          var bEntryTree = await objStorage.read(bEntry.hash).getOrThrow();

          var newTreeHash = await _combineTrees(
            aEntryTree as GitTree,
            bEntryTree as GitTree,
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

    var newTree = GitTree.empty();
    newTree.entries = entries;

    return objStorage.writeObject(newTree);
  }

  // Convenience method
  Future<Result<void>> mergeCurrentTrackingBranch({
    required GitAuthor author,
  }) =>
      catchAll(() => _mergeTrackingBranch(author: author));

  Future<Result<void>> _mergeTrackingBranch({required GitAuthor author}) async {
    var branch = await currentBranch().getOrThrow();
    var branchConfig = config.branch(branch);
    if (branchConfig == null) {
      throw Exception("Branch '$branch' not in config");
    }

    if (branchConfig.trackingBranch() == null) {
      throw Exception("Branch '$branch' has no tracking branch");
    }
    var remoteBranchRef = await remoteBranch(
      branchConfig.remote!,
      branchConfig.trackingBranch()!,
    ).getOrThrow();

    var hash = remoteBranchRef.hash!;
    var commit = await objStorage.readCommit(hash).getOrThrow();
    await merge(
      theirCommit: commit,
      author: author,
      message: 'Merge ${branchConfig.remoteTrackingBranch()}',
    ).throwOnError();

    return Result(null);
  }

  Future<Result<void>> resetHard(GitHash hash) async {
    var headR = await head();
    if (headR.isFailure) {
      return fail(headR);
    }
    var headRef = headR.getOrThrow();

    var branchNameRef = headRef.target!;
    assert(branchNameRef.isBranch());

    var newRef = Reference.hash(branchNameRef, hash);
    var saveRefResult = await refStorage.saveRef(newRef);
    if (saveRefResult.isFailure) {
      return fail(saveRefResult);
    }

    var res = await checkout('.');
    if (res.isFailure) {
      return fail(res);
    }

    return Result(null);
  }
}
