// ignore_for_file: avoid_print

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/git_hash.dart';

class ResetCommand extends Command<int> {
  @override
  final name = 'reset';

  @override
  final description = 'Reset current HEAD to the specified state';

  final String currentDir;

  ResetCommand(this.currentDir) {
    argParser.addFlag('hard', defaultsTo: false);
  }

  @override
  int run() {
    var gitRootDir = GitRepository.findRootDir(currentDir)!;
    var repo = GitRepository.load(gitRootDir);

    print(argResults!.rest);

    var arg = argResults!.rest[0];
    if (arg.isEmpty) {
      print('No args provided');
      return 1;
    }

    var headCommit = repo.headCommit();
    assert(headCommit.parents.length == 1);
    var targetHash = arg == 'HEAD^' ? headCommit.parents[0] : GitHash(arg);

    var hard = argResults!['hard'] as bool;
    if (hard) {
      // do it
      repo.resetHard(targetHash);
      print('HEAD is now at $targetHash');
    }

    return 0;
  }
}
