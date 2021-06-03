import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';

class AddCommand extends Command {
  @override
  final name = 'add';

  @override
  final description = 'Add file contents to the index';

  @override
  Future run() async {
    // FIXME: if gitRootDir is not valid give an error!
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = await GitRepository.load(gitRootDir).getOrThrow();

    var pathSpec = argResults!.arguments[0];
    await repo.add(pathSpec);

    // FIXME: Get proper pathSpec
    // FIXME: Handle glob patterns
    // FIXME: Handle .
  }
}
