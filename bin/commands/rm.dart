// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/git.dart';

class RmCommand extends Command<int> {
  @override
  final name = 'rm';

  @override
  final description = 'Remove files from the working tree and from the index';

  final String currentDir;

  RmCommand(this.currentDir);

  @override
  int run() {
    var gitRootDir = GitRepository.findRootDir(currentDir)!;
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
    var absFilePath = p.join(currentDir, filePath);
    if (File(absFilePath).existsSync()) {
      File(absFilePath).deleteSync(recursive: true);
    }
    repo.indexStorage.writeIndex(index);

    print("rm '${repo.toPathSpec(filePath)}'");

    // FIXME: Get proper pathSpec
    // FIXME: Handle glob patterns
    // FIXME: Handle .

    return 0;
  }
}
