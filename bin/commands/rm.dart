import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';

class RmCommand extends Command {
  @override
  final name = 'rm';

  @override
  final description = 'Remove files from the working tree and from the index';

  @override
  void run() {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = GitRepository.load(gitRootDir).getOrThrow();

    var filePath = argResults!.arguments[0];
    var index = repo.indexStorage.readIndex().getOrThrow();

    // FIXME: Use rm method, do we ever need to read the index?
    var hashR = repo.rmFileFromIndex(index, filePath);
    if (hashR.isFailure) {
      print("fatal: pathspec '$filePath' did not match any files");
      return;
    }
    if (File(filePath).existsSync()) {
      File(filePath).deleteSync(recursive: true);
    }
    repo.indexStorage.writeIndex(index).throwOnError();

    print("rm '${repo.toPathSpec(filePath)}'");

    // FIXME: Get proper pathSpec
    // FIXME: Handle glob patterns
    // FIXME: Handle .
  }
}
