import 'package:dart_git/dart_git.dart';
import 'package:dart_git/exceptions.dart';

extension Merge on GitRepository {
  Future<Result<void>> merge(GitCommit commitB) async {
    var headComR = await headCommit();
    if (headComR.isFailure) {
      return fail(headComR);
    }
    var commitA = headComR.getOrThrow();
    var baseR = await mergeBase(commitA, commitB);
    if (baseR.isFailure) {
      return fail(baseR);
    }
    var bases = baseR.getOrThrow();

    if (bases.length > 1) {
      var ex = GitMergeTooManyBases();
      return Result.fail(ex);
    }
    var base = bases.first;

    // - fastforward
    // FIXME: Use reset?
    if (base.hash == commitA.hash) {
      // set head to commitA
      return Result(null);
    } else if (base.hash == commitB.hash) {
      return Result(null);
    }

    // - normal
    //   - ours
    //   - theirs
    // - up to date
    // - unborn ?
    return Result(null);
  }
}
