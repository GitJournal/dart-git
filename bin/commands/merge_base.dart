// ignore_for_file: avoid_print

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/git_hash.dart';

class MergeBaseCommand extends Command<int> {
  @override
  final name = 'merge-base';

  @override
  final description = 'Find as good common ancestors as possible for a merge';

  final String currentDir;

  MergeBaseCommand(this.currentDir) {
    argParser.addFlag('independent', defaultsTo: false);
  }

  @override
  int run() {
    var args = argResults!.rest;
    if (args.length != 2) {
      print('Incorrect usage');
      return 1;
    }

    var gitRootDir = GitRepository.findRootDir(currentDir)!;
    var repo = GitRepository.load(gitRootDir);

    var aHash = GitHash(args[0]);
    var bHash = GitHash(args[1]);

    var aRes = repo.objStorage.readCommit(aHash);
    var bRes = repo.objStorage.readCommit(bHash);

    var independent = argResults!['independent'] as bool;
    var commits = independent
        ? repo.independents([aRes, bRes])
        : repo.mergeBase(aRes, bRes);
    for (var c in commits) {
      print(c.hash);
    }

    return 0;
  }
}
