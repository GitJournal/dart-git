import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/objects/blob.dart';

class CatFileCommand extends Command {
  @override
  final name = 'cat-file';

  @override
  final description =
      'Provide content or type and size information for repository objects';

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path);
    var repo = await GitRepository.load(gitRootDir);

    var objectSha1 = argResults.arguments[1];
    var obj = await repo.objStorage.readObjectFromHash(GitHash(objectSha1));
    if (obj is GitBlob) {
      var s = utf8.decode(obj.blobData);
      print(s);
    }
  }
}
