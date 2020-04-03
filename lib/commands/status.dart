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
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path);
    var repo = await GitRepository.load(gitRootDir);

    var head = await repo.head();
    if (head.isHash) {
      print('HEAD detached at ${head.hash}');
    } else {
      print('On branch ${head.target.branchName()}');
    }

    if (head.isHash) {
      return;
    }

    var branch = repo.branch(head.target.branchName());

    // Construct remote's branch
    var remoteBranchName = branch.merge.branchName();
    var remoteRef = ReferenceName.remote(branch.remote, remoteBranchName);

    var headHash = (await repo.resolveReference(head)).hash;
    var remoteHash = (await repo.resolveReferenceName(remoteRef)).hash;

    if (headHash != remoteHash) {
      print('Your branch is not equal to $remoteRef');
    }

    //"Changes not staged for commit:"
    //"Untracked files:"
  }
}
