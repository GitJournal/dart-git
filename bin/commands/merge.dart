import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';

class MergeCommand extends Command {
  @override
  final name = 'merge';

  @override
  final description = 'Join two or more development histories together';

  @override
  Future run() async {
    var args = argResults!.rest;
    if (args.length != 1) {
      print('Incorrect usage');
      return;
    }

    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = await GitRepository.load(gitRootDir).getOrThrow();
    var branchCommit = await repo.branchCommit(args[0]).getOrThrow();

    await repo.merge(branchCommit).throwOnError();
  }
}
