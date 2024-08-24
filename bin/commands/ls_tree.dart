// ignore_for_file: avoid_print

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';

class LsTreeCommand extends Command<int> {
  @override
  final name = 'ls-tree';

  @override
  final description = 'List the contents of a tree object';

  final String currentDir;

  LsTreeCommand(this.currentDir);

  @override
  int run() {
    var objectSha1 = argResults!.rest.first;

    var gitRootDir = GitRepository.findRootDir(currentDir)!;
    var repo = GitRepository.load(gitRootDir);

    var objRes = repo.objStorage.read(GitHash(objectSha1));
    var obj = objRes;
    GitTree? tree;
    if (obj is GitTree) {
      tree = obj;
    } else if (obj is GitCommit) {
      tree = repo.objStorage.readTree(obj.treeHash);
    } else {
      assert(false);
    }

    for (var leaf in tree!.entries) {
      var leafObj = repo.objStorage.read(leaf.hash);
      if (leafObj == null) {
        print('error: object ${leaf.hash} not found');
        return 1;
      }
      var type = leafObj.formatStr();
      var mode = leaf.mode.toString().padLeft(6, '0');
      print('$mode $type ${leaf.hash}    ${leaf.name}');
    }

    return 0;
  }
}
