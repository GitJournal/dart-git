import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';

class LogCommand extends Command {
  @override
  final name = 'log';

  @override
  final description = 'Show commit logs';

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = await GitRepository.load(gitRootDir).getOrThrow();

    GitHash? sha;
    if (argResults!.rest.isNotEmpty) {
      sha = GitHash(argResults!.rest.first);
    } else {
      var result = await repo.headHash();
      if (result.isFailure) {
        print('fatal: head hash not found');
        return;
      }
      sha = result.getOrThrow();
    }

    var seen = <GitHash>{};
    var parents = <GitHash?>[];
    parents.add(sha);

    while (parents.isNotEmpty) {
      var sha = parents[0]!;
      parents.removeAt(0);
      seen.add(sha);

      var objRes = await repo.objStorage.readCommit(sha);
      if (objRes.isFailure) {
        print('panic: object with sha $sha not found');
        return;
      }
      var commit = objRes.getOrThrow();

      printCommit(commit, sha);
      for (var p in commit.parents) {
        if (seen.contains(p)) continue;
        parents.add(p);
      }
    }
  }
}

void printCommit(GitCommit commit, GitHash sha) {
  var author = commit.author;

  print('commit $sha');
  print('Author: ${author.name} <${author.email}>');
  print('Date:   ${author.date.toIso8601String()}');
  print('');
  for (var line in LineSplitter.split(commit.message)) {
    print('    $line');
  }
  print('');
}
