// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/utils/utils.dart';

class CheckoutCommand extends Command {
  @override
  final name = 'checkout';

  @override
  final description = 'Switch branches or restore working tree files';

  CheckoutCommand() {
    argParser.addOption('branch', abbr: 'b', defaultsTo: '');
  }

  @override
  void run() {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = GitRepository.load(gitRootDir).getOrThrow();

    var branchName = argResults!['branch'] as String;
    if (branchName.isNotEmpty) {
      var remoteFullBranchName = '';
      if (argResults!.rest.isNotEmpty) {
        remoteFullBranchName = argResults!.rest[0];
      } else {
        var branches = repo.branches().getOrThrow();
        if (branches.contains(branchName)) {
          repo.checkoutBranch(branchName).throwOnError();
          return;
        } else {
          // FIXME: This should lookup which remote has it
          remoteFullBranchName = 'origin/$branchName';
        }
      }

      var remoteName = splitPath(remoteFullBranchName).item1;
      var remoteBranchName = splitPath(remoteFullBranchName).item2;

      var remoteRefR = repo.remoteBranch(remoteName, remoteBranchName);
      if (remoteRefR.isFailure) {
        print('fatal: remote $remoteName branch $remoteBranchName not found');
        return;
      }
      var remoteRef = remoteRefR.getOrThrow();

      repo.createBranch(branchName, hash: remoteRef.hash).throwOnError();
      repo.checkout('.').throwOnError();
      repo
          .setUpstreamTo(repo.config.remote(remoteName)!, remoteBranchName)
          .throwOnError();
      print(
          "Branch '$branchName' set up to track remote branch '$remoteBranchName' from '$remoteName'.");

      var headRefResult = repo.head();
      if (headRefResult.isFailure) {
        print('fatal: head not found');
        return;
      }

      var headRef = headRefResult.getOrThrow();
      if (headRef.target!.branchName() == branchName) {
        print("Already on '$branchName'");
      }

      return;
    }

    if (argResults!.arguments.isEmpty) {
      print('Must provide a file');
      return;
    }

    var pathSpec = argResults!.arguments[0];
    var branches = repo.branches().getOrThrow();
    if (branches.contains(pathSpec)) {
      repo.checkoutBranch(pathSpec).throwOnError();
      return;
    }

    // TODO: Check if one of the remotes contains this branch

    var objectsUpdatedR = repo.checkout(pathSpec);

    if (objectsUpdatedR.isFailure) {
      print(
          "error: pathspec '$pathSpec' did not match any file(s) known to git");
      return;
    }
    var objectsUpdated = objectsUpdatedR.getOrThrow();
    print('Updated $objectsUpdated path from the index');
  }
}
