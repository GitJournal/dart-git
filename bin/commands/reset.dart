import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';

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
    if (arg != 'HEAD^') {
      print('Only supports HEAD^');
      return;
    }

    var headCommit = await repo.headCommit().getOrThrow();
    var targetHash = headCommit.parents[0];

    var hard = argResults!['hard'] as bool;
    if (hard) {
      // do it
      await repo.resetHard(targetHash).throwOnError();
      print('HEAD is now at $targetHash');
    }
  }
}
