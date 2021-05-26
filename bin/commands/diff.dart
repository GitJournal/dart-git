import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/diff_commit.dart';
import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/git_hash.dart';

class DiffCommand extends Command {
  @override
  final name = 'diff';

  @override
  final description =
      'Show changes between commits, commit and working tree, etc';

  DiffCommand() {
    argParser.addFlag('raw');
  }

  @override
  Future run() async {
    var raw = argResults!['raw'] as bool?;
    if (raw == false) {
      print('Only supported with --raw');
      return 1;
    }

    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = await GitRepository.load(gitRootDir).get();

    var fromStr = argResults!.arguments[0];
    var toStr = argResults!.arguments[1];

    var fromCommitRes = await repo.objStorage.readCommit(GitHash(fromStr));
    var toCommitRes = await repo.objStorage.readCommit(GitHash(toStr));

    var fromCommit = fromCommitRes.get();
    var toCommit = toCommitRes.get();

    var changes = await diffCommits(
      fromCommit: fromCommit,
      toCommit: toCommit,
      objStore: repo.objStorage,
    );

    for (var r in changes.merged()) {
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

      print(':$prevMode $newMode $prevHash $newHash $state\t${r.path}');
    }
  }
}
