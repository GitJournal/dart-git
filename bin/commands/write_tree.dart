// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';

class WriteTreeCommand extends Command<int> {
  @override
  final name = 'write-tree';

  @override
  final description = 'Create a tree object from the current index';

  @override
  int run() {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = GitRepository.load(gitRootDir);

    var index = repo.indexStorage.readIndex();
    var hash = repo.writeTree(index);
    print(hash);

    return 0;
  }
}
