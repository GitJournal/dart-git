import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/utils/utils.dart';

class BranchCommand extends Command {
  @override
  final name = 'branch';

  @override
  final description = 'List, create, or delete branches';

  BranchCommand() {
    argParser.addOption('set-upstream-to');
    argParser.addFlag('all', abbr: 'a', defaultsTo: false);
    argParser.addFlag('delete', abbr: 'd', defaultsTo: false);
  }

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = await GitRepository.load(gitRootDir).getOrThrow();

    var showAll = argResults!['all'] as bool?;
    var delete = argResults!['delete'] as bool?;

    var hasNoArgs = argResults!['set-upstream-to'] == null && delete == false;
    if (hasNoArgs) {
      if (argResults!.rest.isEmpty) {
        var headResult = await repo.head();
        if (headResult.isFailure) {
          print('fatal: no head');
          return;
        }

        var head = headResult.getOrThrow();
        if (head.isHash) {
          print('* (HEAD detached at ${head.hash!.toOid()})');
        }

        var branches = await repo.branches().getOrThrow();
        branches.sort();

        for (var branch in branches) {
          if (head.isSymbolic && head.target!.branchName() == branch) {
            print('* ${head.target!.branchName()}');
            continue;
          }
          print('  $branch');
        }

        if (showAll!) {
          for (var remote in repo.config.remotes) {
            var refs = await repo.remoteBranches(remote.name).getOrThrow();
            refs.sort((a, b) {
              return a.name.branchName()!.compareTo(b.name.branchName()!);
            });

            for (var ref in refs) {
              var branch = ref.name.branchName();
              if (ref.isHash) {
                print('  remotes/${remote.name}/$branch');
              } else {
                var tb = ref.target!.branchName();
                if (ref.target!.isRemote()) {
                  tb = '${ref.target!.remoteName()}/$tb';
                }
                print('  remotes/${remote.name}/$branch -> $tb');
              }
            }
          }
        }
        return;
      } else {
        var rest = argResults!.rest;

        if (rest.length == 1) {
          var name = argResults!.rest.first;
          var hashR = await repo.createBranch(name);
          if (hashR.isFailure) {
            print("fatal: A branch named '$name' already exists.");
          }
        } else {
          var parts = splitPath(argResults!.rest[1]);
          var remoteName = parts.item1;
          var remoteBranchName = parts.item2;
          var branchName = rest.first;

          var refName = ReferenceName.remote(remoteName, remoteBranchName);
          var refResult = await repo.resolveReferenceName(refName);
          if (refResult.isFailure) {
            print('fatal');
            return;
          }

          var ref = refResult.getOrThrow();
          assert(ref.isHash);
          await repo.createBranch(branchName, hash: ref.hash);

          var remote = repo.config.remote(remoteName)!;
          await repo.setBranchUpstreamTo(branchName, remote, remoteBranchName);

          print(
              "Branch '$branchName' set up to track remote branch '$remoteBranchName' from '$remoteName'.");
        }
        return;
      }
    }

    if (delete!) {
      if (argResults!.rest.isEmpty) {
        print('fatal: branch name required');
        return;
      }
      var branchName = argResults!.rest.first;
      var hashR = await repo.deleteBranch(branchName);
      if (hashR.isFailure) {
        print("error: branch '$branchName' not found.");
        return;
      }
      var hash = hashR.getOrThrow();
      print('Deleted branch $branchName (was ${hash.toOid()}).');
      return;
    }

    var upstream = argResults!['set-upstream-to'] as String;
    if (!upstream.contains('/')) {
      // FIXME: We need to check if a local branch with this name exists!
      print("error: the requested upstream branch '$upstream' does not exist");
    }

    var parts = splitPath(upstream);
    var remoteName = parts.item1;
    var remoteBranchName = parts.item2;

    var remote = repo.config.remote(remoteName);
    if (remote == null) {
      print("error: the requested upstream branch '$upstream' does not exist");
      return;
    }

    var localBranch =
        await repo.setUpstreamTo(remote, remoteBranchName).getOrThrow();

    print(
        "Branch '${localBranch.name}' set up to track remote branch '$remoteBranchName' from '$remoteName'.");
  }
}
