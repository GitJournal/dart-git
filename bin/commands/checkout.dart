// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/utils/utils.dart';

class CheckoutCommand extends Command<int> {
  @override
  final name = 'checkout';

  @override
  final description = 'Switch branches or restore working tree files';

  CheckoutCommand() {
    argParser.addOption('branch', abbr: 'b', defaultsTo: '');
  }

  @override
  int run() {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = GitRepository.load(gitRootDir);

    var branchName = argResults!['branch'] as String;
    if (branchName.isNotEmpty) {
      var remoteFullBranchName = '';
      if (argResults!.rest.isNotEmpty) {
        remoteFullBranchName = argResults!.rest[0];
      } else {
        var branches = repo.branches();
        if (branches.contains(branchName)) {
          repo.checkoutBranch(branchName);
          return 0;
        } else {
          // FIXME: This should lookup which remote has it
          remoteFullBranchName = 'origin/$branchName';
        }
      }

      var remoteName = splitPath(remoteFullBranchName).item1;
      var remoteBranchName = splitPath(remoteFullBranchName).item2;

      late HashReference remoteRef;
      try {
        remoteRef = repo.remoteBranch(remoteName, remoteBranchName);
      } catch (ex) {
        // FIXME: Catch the exact exception
        print('fatal: remote $remoteName branch $remoteBranchName not found');
        return 1;
      }

      repo.createBranch(branchName, hash: remoteRef.hash);
      repo.checkoutBranch(branchName);
      repo.setUpstreamTo(repo.config.remote(remoteName)!, remoteBranchName);
      print(
          "Branch '$branchName' set up to track remote branch '$remoteBranchName' from '$remoteName'.");

      try {
        var headRef = repo.head();
        switch (headRef) {
          case SymbolicReference():
            if (headRef.target.branchName() == branchName) {
              print("Already on '$branchName'");
            }
          case HashReference():
        }

        return 0;
      } catch (ex) {
        // FIXME: Catch the exact exception
        print('fatal: head not found');
        return 1;
      }
    }

    if (argResults!.arguments.isEmpty) {
      print('Must provide a file');
      return 1;
    }

    var pathSpec = argResults!.arguments[0];
    var branches = repo.branches();
    if (branches.contains(pathSpec)) {
      repo.checkoutBranch(pathSpec);
      return 0;
    }

    // TODO: Check if one of the remotes contains this branch
    try {
      var objectsUpdated = repo.checkout(pathSpec);
      print('Updated $objectsUpdated path from the index');
      return 0;
    } catch (ex) {
      // FIXME: Catch the exact exception
      print(
          "error: pathspec '$pathSpec' did not match any file(s) known to git");
      return 1;
    }
  }
}
