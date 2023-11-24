// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/reference.dart';

class StatusCommand extends Command<int> {
  @override
  final name = 'status';

  @override
  final description = 'Show the working tree status';

  @override
  int run() {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = GitRepository.load(gitRootDir);

    late Reference head;
    try {
      head = repo.head();
    } catch (ex) {
      // FIXME: Catch the exact exception
      print('fatal: no head found');
      return 1;
    }
    switch (head) {
      case HashReference():
        print('HEAD detached at ${head.hash.toOid()}');
        return 0;
      case SymbolicReference _:
    }

    print('On branch ${head.target.branchName()}');
    var branch = repo.config.branch(head.target.branchName()!);

    // Construct remote's branch
    if (branch != null) {
      var remoteBranchName = branch.merge!.branchName()!;
      var remoteRefN = ReferenceName.remote(branch.remote!, remoteBranchName);

      var headHash = repo.resolveReference(head).hash;
      var remoteHash = repo.resolveReferenceName(remoteRefN)?.hash;

      if (remoteHash == null) {
        print('fatal: unable to resolve reference');
        return 1;
      }

      var remoteStr = '${branch.remote}/$remoteBranchName';
      if (headHash != remoteHash) {
        var aheadBy = repo.countTillAncestor(headHash, remoteHash);
        if (aheadBy != -1) {
          print('Your branch is ahead of $remoteStr by $aheadBy commits');
        } else {
          var behindBy = repo.countTillAncestor(remoteHash, headHash);
          if (behindBy != -1) {
            print('Your branch is behind $remoteStr by $behindBy commits');
          } else {
            print('Your branch is not equal to $remoteRefN');
          }
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

    return 0;
  }
}
