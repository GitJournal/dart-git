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
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = await GitRepository.load(gitRootDir).get();

    var filePath = argResults!.arguments[0];
    var index = await repo.indexStorage.readIndex().get();

    var hash = await repo.rmFileFromIndex(index, filePath);
    if (hash == null) {
      print("fatal: pathspec '$filePath' did not match any files");
      return;
    }
    if (File(filePath).existsSync()) {
      await File(filePath).delete(recursive: true);
    }
    await repo.indexStorage.writeIndex(index);

    print("rm '${repo.toPathSpec(filePath)}'");

    // FIXME: Get proper pathSpec
    // FIXME: Handle glob patterns
    // FIXME: Handle .
  }
}
