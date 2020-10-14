import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_git/config.dart';

import 'package:dart_git/git.dart';

class BranchCommand extends Command {
  @override
  final name = 'branch';

  @override
  final description = 'List, create, or delete branches';

  BranchCommand() {
    argParser.addOption('set-upstream-to');
  }

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path);
    var repo = await GitRepository.load(gitRootDir);

    var hasNoArgs = argResults['set-upstream-to'] == null;
    if (hasNoArgs) {
      if (argResults.arguments.isEmpty) {
        var head = await repo.head();
        if (head.isHash) {
          print('* (HEAD detached at ${head.hash.toOid()})');
        } else {}

        var branches = await repo.branches();
        branches.sort();

        for (var branch in branches) {
          if (head.isSymbolic && head.target.branchName() == branch) {
            print('* ${head.target.branchName()}');
            continue;
          }
          print('  $branch');
        }
        return;
      } else {
        await repo.createBranch(argResults.arguments.first);
        return;
      }
    }

    var upstream = argResults['set-upstream-to'] as String;
    if (!upstream.contains('/')) {
      // FIXME: We need to check if a local branch with this name exists!
      print("error: the requested upstream branch '$upstream' does not exist");
    }

    var parts = upstream.split('/');
    var remoteName = parts[0];
    var remoteBranchName = parts[1];

    var remote = repo.remote(remoteName);
    if (remote == null) {
      print("error: the requested upstream branch '$upstream' does not exist");
    }

    BranchConfig localBranch;
    try {
      localBranch = await repo.setUpstreamTo(remote, remoteBranchName);
    } catch (e) {
      print(e);
    }

    print(
        "Branch '${localBranch.name}' set up to track remote branch '$remoteBranchName' from '$remoteName'.");
  }
}
