import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';

class RemoteCommand extends Command {
  @override
  final name = 'remote';

  @override
  final description = 'Manage set of tracked repositories';

  RemoteCommand() {
    argParser.addFlag('verbose', abbr: 'v', defaultsTo: false);
  }

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path);
    var repo = await GitRepository.load(gitRootDir);

    var verbose = argResults['verbose'] as bool;

    for (var remote in repo.remotes()) {
      if (!verbose) {
        print(remote.name);
      } else {
        print('${remote.name}\t${remote.url} (fetch)');
        print('${remote.name}\t${remote.url} (push)');
      }
    }
  }
}
