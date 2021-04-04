// @dart=2.9

import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';

class AddCommand extends Command {
  @override
  final name = 'add';

  @override
  final description = 'Add file contents to the index';

  AddCommand() {
    //argParser.addCommand(name);
  }

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path);
    var repo = await GitRepository.load(gitRootDir);

    var filePath = argResults.arguments[0];
    var index = await repo.readIndex();

    try {
      await repo.addFileToIndex(index, filePath);
    } catch (e) {
      print(e);
    }

    await repo.writeIndex(index);

    // FIXME: Get proper pathSpec
    // FIXME: Handle glob patterns
    // FIXME: Handle .
  }
}
