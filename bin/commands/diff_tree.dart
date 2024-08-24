// ignore_for_file: avoid_print

import 'package:args/command_runner.dart';

import 'package:dart_git/diff_tree.dart';
import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';

class DiffTreeCommand extends Command<int> {
  @override
  final name = 'diff-tree';

  @override
  final description =
      'Compares the content and mode of blobs found via two tree objects';

  final String currentDir;

  DiffTreeCommand(this.currentDir);

  @override
  int run() {
    var gitRootDir = GitRepository.findRootDir(currentDir)!;
    var repo = GitRepository.load(gitRootDir);

    var hash = argResults!.arguments[0];
    var obj = repo.objStorage.read(GitHash(hash));
    if (obj == null) {
      print('error: object $hash not found');
      return 1;
    }
    if (obj is! GitCommit) {
      print('error: object $hash is a ${obj.formatStr()}, not a commit');
      return 1;
    }
    var commit = obj;
    var parentHash = commit.parents.first;
    var parentObj = repo.objStorage.readCommit(parentHash);

    var results = diffTree(
      from: repo.objStorage.readTree(parentObj.treeHash),
      to: repo.objStorage.readTree(obj.treeHash),
    );

    print(hash);
    for (var r in results.merged()) {
      var prevMode = ''.padLeft(6, '0');
      var newMode = ''.padLeft(6, '0');
      var prevHash = ''.padLeft(40, '0');
      var newHash = ''.padLeft(40, '0');

      var state = 'M';
      if (r.add) {
        state = 'A';
        newMode = r.to!.mode.toString().padLeft(6, '0');
        newHash = r.to!.hash.toString();
      } else if (r.delete) {
        state = 'D';
        prevMode = r.from!.mode.toString().padLeft(6, '0');
        prevHash = r.from!.hash.toString();
      } else {
        newMode = r.to!.mode.toString().padLeft(6, '0');
        newHash = r.to!.hash.toString();
        prevMode = r.from!.mode.toString().padLeft(6, '0');
        prevHash = r.from!.hash.toString();
      }

      print(':$prevMode $newMode $prevHash $newHash $state\t${r.name}');
    }

    return 0;
  }
}
