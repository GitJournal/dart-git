// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/git_hash.dart';

class CatFileCommand extends Command<int> {
  @override
  final name = 'cat-file';

  @override
  final description =
      'Provide content or type and size information for repository objects';

  @override
  int run() {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = GitRepository.load(gitRootDir);

    var objectSha1 = argResults!.arguments[1];
    var obj = repo.objStorage.read(GitHash(objectSha1));
    if (obj == null) {
      print('Object not found');
      return 1;
    }
    var s = utf8.decode(obj.serializeData());
    print(s);

    return 0;
  }
}
