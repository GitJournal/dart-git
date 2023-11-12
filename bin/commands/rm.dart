// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';

class RmCommand extends Command<int> {
  @override
  final name = 'rm';

  @override
  final description = 'Remove files from the working tree and from the index';

  @override
  int run() {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = GitRepository.load(gitRootDir);

    var filePath = argResults!.arguments[0];
    var index = repo.indexStorage.readIndex();

    // FIXME: Use rm method, do we ever need to read the index?
    try {
      repo.rmFileFromIndex(index, filePath);
    } catch (ex) {
      // FIXME: Catch the exact exception
      print("fatal: pathspec '$filePath' did not match any files");
      return 1;
    }
    if (File(filePath).existsSync()) {
      File(filePath).deleteSync(recursive: true);
    }
    repo.indexStorage.writeIndex(index);

    print("rm '${repo.toPathSpec(filePath)}'");

    // FIXME: Get proper pathSpec
    // FIXME: Handle glob patterns
    // FIXME: Handle .

    return 0;
  }
}
