import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/reference.dart';

class StatusCommand extends Command {
  @override
  final name = 'status';

  @override
  final description = 'Show the working tree status';

  @override
  void run() {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = GitRepository.load(gitRootDir).getOrThrow();

    var headResult = repo.head();
    if (headResult.isFailure) {
      print('fatal: no head found');
      return;
    }

    var head = headResult.getOrThrow();
    if (head.isHash) {
      print('HEAD detached at ${head.hash}');
    } else {
      print('On branch ${head.target!.branchName()}');
    }

    if (head.isHash) {
      return;
    }

    var branch = repo.config.branch(head.target!.branchName()!)!;

    // Construct remote's branch
    var remoteBranchName = branch.merge!.branchName()!;
    var remoteRef = ReferenceName.remote(branch.remote!, remoteBranchName);

    var headHash = (repo.resolveReference(head)).getOrThrow().hash;
    var remoteHash = (repo.resolveReferenceName(remoteRef)).getOrThrow().hash;

    var remoteStr = '${branch.remote}/$remoteBranchName';
    if (headHash != remoteHash) {
      var aheadBy = repo.countTillAncestor(headHash!, remoteHash!).getOrThrow();
      if (aheadBy != -1) {
        print('Your branch is ahead of $remoteStr by $aheadBy commits');
      } else {
        var behindBy =
            repo.countTillAncestor(remoteHash, headHash).getOrThrow();
        if (behindBy != -1) {
          print('Your branch is behind $remoteStr by $behindBy commits');
        } else {
          print('Your branch is not equal to $remoteRef');
        }
      }
    }

    //"Changes not staged for commit:"
    //"Untracked files:"

    print('Changes to be committed:');
    print('  (use "git reset HEAD <file>..." to unstage))\n');

    // Print one of the following -
    // new file: path
    // deleted: path
    // modified: path

    // Get the head commit
    // Get the tree
    // iterate over all objects in the tree and check if present in the index
    // make sure that for each path, the hash in the index is the same
  }
}
