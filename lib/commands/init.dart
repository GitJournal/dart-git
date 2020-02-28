import 'package:args/command_runner.dart';
import 'package:dart_git/git.dart';

class InitCommand extends Command {
  @override
  final name = 'init';

  @override
  final description =
      'Create an empty Git repository or reinitialize an existing one';

  @override
  Future run() async {
    if (argResults.rest.isEmpty) {
      print('Must provde a path');
      return false;
    }

    var path = argResults.rest.first;
    await GitRepository.init(path);

    print('Initialized empty Git repository in $path');
  }
}
