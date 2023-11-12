// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/commit_iterator.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';

class LogCommand extends Command<int> {
  @override
  final name = 'log';

  @override
  final description = 'Show commit logs';

  @override
  int run() {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = GitRepository.load(gitRootDir);

    GitHash? sha;
    if (argResults!.rest.isNotEmpty) {
      sha = GitHash(argResults!.rest.first);
    } else {
      try {
        sha = repo.headHash();
      } catch (ex) {
        print('fatal: head hash not found');
        return 1;
      }
    }

    var iter = commitIteratorBFS(objStorage: repo.objStorage, from: sha);
    for (var result in iter) {
      var commit = result;
      printCommit(commit, sha);
    }

    return 0;
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
