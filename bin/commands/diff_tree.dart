import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/diff_tree.dart';
import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/utils/result.dart';

class DiffTreeCommand extends Command {
  @override
  final name = 'diff-tree';

  @override
  final description =
      'Compares the content and mode of blobs found via two tree objects';

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = await GitRepository.load(gitRootDir).getOrThrow();

    var hash = argResults!.arguments[0];
    var objRes = await repo.objStorage.read(GitHash(hash));
    if (objRes.isFailure) {
      print('fatal: bad object $hash');
      return;
    }
    var obj = objRes.getOrThrow();

    if (obj is! GitCommit) {
      print('error: object $hash is a ${obj.formatStr()}, not a commit');
      return;
    }
    var commit = obj;
    var parentHash = commit.parents.first;
    var parentObj = await repo.objStorage.read(parentHash);

    var taHash = (parentObj as GitCommit).treeHash;
    var tbHash = obj.treeHash;

    var results = diffTree(
      await repo.objStorage.readTree(taHash).getOrThrow(),
      await repo.objStorage.readTree(tbHash).getOrThrow(),
    );

    for (var r in results.merged()) {
      var prevMode = ''.padLeft(6, '0');
      var newMode = ''.padLeft(6, '0');
      var prevHash = ''.padLeft(40, '0');
      var newHash = ''.padLeft(40, '0');

      var state = 'M';
      if (r.added) {
        state = 'A';
        newMode = r.to!.mode.toString().padLeft(6, '0');
        newHash = r.to!.hash.toString();
      } else if (r.deleted) {
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
  }
}
