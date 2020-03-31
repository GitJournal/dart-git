import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_git/git.dart';

class BranchCommand extends Command {
  @override
  final name = 'branch';

  @override
  final description = 'List, create, or delete branches';

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path);
    var repo = await GitRepository.load(gitRootDir);

    for (var branch in repo.branches()) {
      print(branch.name);
    }
  }
}
