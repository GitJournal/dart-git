import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/git_hash.dart';

class CatFileCommand extends Command {
  @override
  final name = 'cat-file';

  @override
  final description =
      'Provide content or type and size information for repository objects';

  @override
  void run() {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = GitRepository.load(gitRootDir).getOrThrow();

    var objectSha1 = argResults!.arguments[1];
    var objRes = repo.objStorage.read(GitHash(objectSha1));
    var obj = objRes.getOrThrow();
    var s = utf8.decode(obj.serializeData());
    print(s);
  }
}
