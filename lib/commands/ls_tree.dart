import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/objects/tree.dart';

class LsTreeCommand extends Command {
  @override
  final name = 'ls-tree';

  @override
  final description = 'List the contents of a tree object';

  @override
  Future run() async {
    var objectSha1 = argResults.rest.first;

    var gitRootDir = GitRepository.findRootDir(Directory.current.path);
    var repo = await GitRepository.load(gitRootDir);

    var obj = await repo.readObjectFromHash(GitHash(objectSha1));
    assert(obj is GitTree);

    var tree = obj as GitTree;
    for (var leaf in tree.leaves) {
      var leafObj = await repo.readObjectFromHash(leaf.hash);
      var type = ascii.decode(leafObj.format());
      print('${leaf.mode.padLeft(6, '0')} $type ${leaf.hash}    ${leaf.path}');
    }
  }
}
