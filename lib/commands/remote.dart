import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_git/git.dart';

class RemoteCommand extends Command {
  @override
  final name = 'remote';

  @override
  final description = 'Manage set of tracked repositories';

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path);
    var repo = await GitRepository.load(gitRootDir);

    for (var remote in repo.remotes()) {
      print(remote.name);
    }
  }
}
