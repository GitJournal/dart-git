// ignore_for_file: avoid_print

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/git.dart';

class InitCommand extends Command<int> {
  @override
  final name = 'init';

  @override
  final description =
      'Create an empty Git repository or reinitialize an existing one';

  final String currentDir;

  InitCommand(this.currentDir) {
    argParser.addFlag('quiet', abbr: 'q', defaultsTo: false);
    argParser.addOption('initial-branch', abbr: 'b', defaultsTo: 'main');
  }

  @override
  int run() {
    if (argResults!.rest.isEmpty) {
      print('Must provide a path');
      return 1;
    }

    var path = p.join(currentDir, argResults!.rest.first);
    var defaultBranch = argResults!['initial-branch'] as String;
    GitRepository.init(path, defaultBranch: defaultBranch);

    var quiet = argResults!['quiet'] as bool;
    if (quiet) {
      return 0;
    }

    var dotGitDir = p.join(p.canonicalize(path), '.git') + p.separator;
    print('Initialized empty Git repository in $dotGitDir');

    return 0;
  }
}
