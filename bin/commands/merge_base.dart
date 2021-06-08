import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/git_hash.dart';

class MergeBaseCommand extends Command {
  @override
  final name = 'merge-base';

  @override
  final description = 'Find as good common ancestors as possible for a merge';

  @override
  Future run() async {
    var args = argResults!.rest;
    if (args.length != 2) {
      print('Incorrect usage');
      return;
    }

    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = await GitRepository.load(gitRootDir).getOrThrow();

    var aHash = GitHash(args[0]);
    var bHash = GitHash(args[1]);

    var aRes = await repo.objStorage.readCommit(aHash);
    var bRes = await repo.objStorage.readCommit(bHash);

    var commits =
        await repo.mergeBase(aRes.getOrThrow(), bRes.getOrThrow()).getOrThrow();
    for (var c in commits) {
      print(c.hash);
    }
  }
}
