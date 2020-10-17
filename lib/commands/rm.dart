import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';

class RmCommand extends Command {
  @override
  final name = 'rm';

  @override
  final description = 'Remove files from the working tree and from the index';

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path);
    var repo = await GitRepository.load(gitRootDir);

    var filePath = argResults.arguments[0];
    var index = await repo.readIndex();

    await repo.rmFileFromIndex(index, filePath);
    await File(filePath).delete(recursive: true);
    await repo.writeIndex(index);

    print("rm '${repo.toPathSpec(filePath)}'");

    // FIXME: Get proper pathSpec
    // FIXME: Handle glob patterns
    // FIXME: Handle .
  }
}
