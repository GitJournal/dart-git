import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';

class LsTreeCommand extends Command {
  @override
  final name = 'ls-tree';

  @override
  final description = 'List the contents of a tree object';

  @override
  void run() {
    var objectSha1 = argResults!.rest.first;

    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = GitRepository.load(gitRootDir).getOrThrow();

    var objRes = repo.objStorage.read(GitHash(objectSha1));
    var obj = objRes.getOrThrow();
    GitTree? tree;
    if (obj is GitTree) {
      tree = obj;
    } else if (obj is GitCommit) {
      tree = repo.objStorage.readTree(obj.treeHash).getOrThrow();
    } else {
      assert(false);
    }

    for (var leaf in tree!.entries) {
      var leafObj = repo.objStorage.read(leaf.hash).getOrThrow();
      var type = leafObj.formatStr();
      var mode = leaf.mode.toString().padLeft(6, '0');
      print('$mode $type ${leaf.hash}    ${leaf.name}');
    }
  }
}
