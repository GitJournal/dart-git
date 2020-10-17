import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';

class CheckoutCommand extends Command {
  @override
  final name = 'checkout';

  @override
  final description = 'Switch branches or restore working tree files';

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path);
    var repo = await GitRepository.load(gitRootDir);

    if (argResults.arguments.isEmpty) {
      print('Must provide a file');
      exit(1);
    }

    var pathSpec = argResults.arguments[0];

    var objectsUpdated = await repo.checkout(pathSpec);

    if (objectsUpdated == null) {
      print(
          "error: pathspec '$pathSpec' did not match any file(s) known to git");
      exit(1);
    }
    print('Updated $objectsUpdated path from the index');
  }
}
