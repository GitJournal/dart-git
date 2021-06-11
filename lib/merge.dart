import 'package:dart_git/dart_git.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/reference.dart';

extension Merge on GitRepository {
  Future<Result<void>> merge(GitCommit commitB) async {
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

    // TODO: Implement merge options -
    // - normal
    //   - ours
    //   - theirs
    // - unborn ?

    var ex = GitException();
    return Result.fail(ex);
  }
}
