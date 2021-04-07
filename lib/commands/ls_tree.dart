import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';

class LsTreeCommand extends Command {
  @override
  final name = 'ls-tree';

  @override
  final description = 'List the contents of a tree object';

  @override
  Future run() async {
    var objectSha1 = argResults!.rest.first;

    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = await GitRepository.load(gitRootDir);

    var obj = await repo.objStorage.readObjectFromHash(GitHash(objectSha1));
    GitTree? tree;
    if (obj is GitTree) {
      tree = obj;
    } else if (obj is GitCommit) {
      tree = await repo.objStorage.readObjectFromHash(obj.treeHash) as GitTree;
    } else {
      assert(false);
    }

    for (var leaf in tree!.entries) {
      var leafObj = (await repo.objStorage.readObjectFromHash(leaf.hash))!;
      var type = leafObj.formatStr();
      var mode = leaf.mode.toString().padLeft(6, '0');
      print('$mode $type ${leaf.hash}    ${leaf.name}');
    }
  }
}
