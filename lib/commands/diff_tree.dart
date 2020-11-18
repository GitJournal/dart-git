import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/diff_tree.dart';

class DiffTreeCommand extends Command {
  @override
  final name = 'diff-tree';

  @override
  final description =
      'Compares the content and mode of blobs found via two tree objects';

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path);
    var repo = await GitRepository.load(gitRootDir);

    var hash = argResults.arguments[0];
    var obj = await repo.objStorage.readObjectFromHash(GitHash(hash));
    if (obj == null) {
      print('fatal: bad object $hash');
      return;
    }

    if (obj is! GitCommit) {
      print('error: object $hash is a ${obj.formatStr()}, not a commit');
      return;
    }

    var head = await repo.headHash();
    var headCommit =
        (await repo.objStorage.readObjectFromHash(head)) as GitCommit;

    var taHash = headCommit.treeHash;
    var tbHash = (obj as GitCommit).treeHash;
    var results = diffTree(
      await repo.objStorage.readObjectFromHash(taHash),
      await repo.objStorage.readObjectFromHash(tbHash),
    );

    for (var r in results.merged()) {
      var prevMode = r.from.mode.toString().padLeft(6, '0');
      var newMode = r.to.mode.toString().padLeft(6, '0');

      var state = 'M';
      if (r.from.mode.isZero) {
        state = 'A';
      } else if (r.to.mode.isZero) {
        state = 'D';
      }

      var path = r.from.path;
      print(':$prevMode $newMode ${r.from.hash} ${r.to.hash} $state\t$path');
    }
  }
}
