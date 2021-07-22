import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/git.dart';

class MergeCommand extends Command {
  @override
  final name = 'merge';

  @override
  final description = 'Join two or more development histories together';

  MergeCommand() {
    argParser.addOption('strategy-option', abbr: 'X');
    argParser.addOption('message', abbr: 'm');
  }

  @override
  Future run() async {
    var args = argResults!.rest;
    if (args.length != 1) {
      print('Incorrect usage');
      return;
    }

    var branchName = args[0];
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = await GitRepository.load(gitRootDir).getOrThrow();
    var branchCommit = await repo.branchCommit(branchName).getOrThrow();

    var user = repo.config.user;
    if (user == null) {
      print('Git user not set. Fetching from env variables');
      user = GitAuthor(
        name: Platform.environment['GIT_AUTHOR_NAME']!,
        email: Platform.environment['GIT_AUTHOR_EMAIL']!,
      );
    }

    var authorDate = Platform.environment['GIT_AUTHOR_DATE'];
    if (authorDate != null) {
      user.date = DateTime.parse(authorDate);
      user.timezoneOffset = 0; // FIXME: Parse this from the env variable
    }

    var committer = user;
    var comitterDate = Platform.environment['GIT_COMMITTER_DATE'];
    if (comitterDate != null) {
      committer.date = DateTime.parse(comitterDate);
    }

    var msg = argResults!['message'] ?? "Merge branch '$branchName'\n";

    await repo
        .merge(
          theirCommit: branchCommit,
          author: user,
          committer: committer,
          message: msg,
        )
        .throwOnError();
  }
}
