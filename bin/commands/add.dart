// ignore_for_file: avoid_print

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';

class AddCommand extends Command<int> {
  @override
  final name = 'add';

  @override
  final description = 'Add file contents to the index';

  final String currentDir;

  AddCommand(this.currentDir);

  @override
  int run() {
    // FIXME: if gitRootDir is not valid give an error!
    var gitRootDir = GitRepository.findRootDir(currentDir)!;
    var repo = GitRepository.load(gitRootDir);

    var pathSpec = argResults!.arguments[0];
    repo.add(pathSpec);

    // FIXME: Get proper pathSpec
    // FIXME: Handle glob patterns
    // FIXME: Handle .

    return 0;
  }
}
