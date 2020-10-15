import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/git_hash.dart';

class MergeBaseCommand extends Command {
  @override
  final name = 'merge-base';

  @override
  final description = 'Find as good common ancestors as possible for a merge';

  @override
  Future run() async {
    var args = argResults.rest;
    if (args.length != 2) {
      print('Incorrect usage');
      return;
    }

    var gitRootDir = GitRepository.findRootDir(Directory.current.path);
    var repo = await GitRepository.load(gitRootDir);

    var aHash = GitHash(args[0]);
    var bHash = GitHash(args[1]);

    var a = await repo.objStorage.readObjectFromHash(aHash);
    var b = await repo.objStorage.readObjectFromHash(bHash);

    if (a == b) {
      print(a.hash());
      return;
    }
  }
}
