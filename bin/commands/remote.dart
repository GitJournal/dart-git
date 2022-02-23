// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';

class RemoteCommand extends Command<int> {
  @override
  final name = 'remote';

  @override
  final description = 'Manage set of tracked repositories';

  final ArgParser addArgParser = ArgParser();
  final ArgParser rmArgParser = ArgParser();

  RemoteCommand() {
    argParser.addFlag('verbose', abbr: 'v', defaultsTo: false);
    var _ = argParser.addCommand('add', addArgParser);
    var __ = argParser.addCommand('rm', rmArgParser);
  }

  @override
  int run() {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = GitRepository.load(gitRootDir).getOrThrow();

    var verbose = argResults!['verbose'] as bool?;

    if (argResults!.command != null) {
      var result = argResults!.command!;
      if (result.name == 'add') {
        if (result.arguments.length != 2) {
          print('usage: git remote add <name> <url>');
          return 1;
        }
        var name = result.arguments[0];
        var url = result.arguments[1];

        repo.addRemote(name, url).throwOnError();
        return 0;
      }

      if (result.name == 'rm') {
        if (result.arguments.length != 1) {
          print('usage: git remote rm <name>');
          return 1;
        }

        var name = result.arguments[0];
        var configResult = repo.removeRemote(name);
        if (configResult.isFailure) {
          print("fatal: No such remote: '$name'");
          return 1;
        }
        return 0;
      }

      return 1;
    }

    for (var remote in repo.config.remotes) {
      if (!verbose!) {
        print(remote.name);
      } else {
        print('${remote.name}\t${remote.url} (fetch)');
        print('${remote.name}\t${remote.url} (push)');
      }
    }

    return 0;
  }
}
