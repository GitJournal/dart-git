import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/git_hash.dart';

class ResetCommand extends Command {
  @override
  final name = 'reset';

  @override
  final description = 'Reset current HEAD to the specified state';

  ResetCommand() {
    argParser.addFlag('hard', defaultsTo: false);
  }

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = await GitRepository.load(gitRootDir).getOrThrow();

    print(argResults!.rest);

    var arg = argResults!.rest[0];
    if (arg.isEmpty) {
      print('No args provided');
      return 1;
    }

    var headCommit = await repo.headCommit().getOrThrow();
    assert(headCommit.parents.length == 1);
    var targetHash = arg == 'HEAD^' ? headCommit.parents[0] : GitHash(arg);

    var hard = argResults!['hard'] as bool;
    if (hard) {
      // do it
      await repo.resetHard(targetHash).throwOnError();
      print('HEAD is now at $targetHash');
    }
  }
}
