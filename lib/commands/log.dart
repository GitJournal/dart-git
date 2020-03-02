import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_git/git.dart';
import 'package:dart_git/git_hash.dart';

class LogCommand extends Command {
  @override
  final name = 'log';

  @override
  final description = 'Show commit logs';

  @override
  Future run() async {
    var sha = argResults.rest.first;

    var repo = GitRepository(Directory.current.path);

    var seen = <String>{};
    var parents = <String>[];
    parents.add(sha);

    while (parents.isNotEmpty) {
      var sha = parents[0];
      parents.removeAt(0);
      seen.add(sha);

      var obj = await repo.readObjectFromHash(GitHash.fromString(sha));
      assert(obj is GitCommit);
      var commit = obj as GitCommit;

      printCommit(repo, commit, sha);
      for (var p in commit.parents) {
        if (seen.contains(p)) continue;
        parents.add(p);
      }
    }
  }

  void printCommit(GitRepository repo, GitCommit commit, String sha) {
    var author = commit.author;

    print('commit $sha');
    print('Author: ${author.name} <${author.email}>');
    print('Date:   ${author.date.toIso8601String()}');
    print('\n    ${commit.message}');
  }
}
