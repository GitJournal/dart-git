import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/git.dart';

class InitCommand extends Command {
  @override
  final name = 'init';

  @override
  final description =
      'Create an empty Git repository or reinitialize an existing one';

  InitCommand() {
    argParser.addFlag('quiet', abbr: 'q', defaultsTo: false);
  }

  @override
  void run() {
    if (argResults!.rest.isEmpty) {
      print('Must provide a path');
      return;
    }

    var path = argResults!.rest.first;
    GitRepository.init(path).throwOnError();

    var quiet = argResults!['quiet'] as bool;
    if (quiet) {
      return;
    }

    var dotGitDir = p.join(p.canonicalize(path), '.git') + p.separator;
    print('Initialized empty Git repository in $dotGitDir');
  }
}
