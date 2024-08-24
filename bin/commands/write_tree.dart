// ignore_for_file: avoid_print

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';

class WriteTreeCommand extends Command<int> {
  @override
  final name = 'write-tree';

  @override
  final description = 'Create a tree object from the current index';

  final String currentDir;

  WriteTreeCommand(this.currentDir);

  @override
  int run() {
    var gitRootDir = GitRepository.findRootDir(currentDir)!;
    var repo = GitRepository.load(gitRootDir);

    var index = repo.indexStorage.readIndex();
    var hash = repo.writeTree(index);
    print(hash);

    return 0;
  }
}
