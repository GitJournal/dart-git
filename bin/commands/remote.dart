import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';

class RemoteCommand extends Command {
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
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = await GitRepository.load(gitRootDir).getOrThrow();

    var verbose = argResults!['verbose'] as bool?;

    if (argResults!.command != null) {
      var result = argResults!.command!;
      if (result.name == 'add') {
        if (result.arguments.length != 2) {
          print('usage: git remote add <name> <url>');
          return;
        }
        var name = result.arguments[0];
        var url = result.arguments[1];

        await repo.addRemote(name, url).throwOnError();
        return;
      }

      if (result.name == 'rm') {
        if (result.arguments.length != 1) {
          print('usage: git remote rm <name>');
          return;
        }

        var name = result.arguments[0];
        var configResult = await repo.removeRemote(name);
        if (configResult.isFailure) {
          print("fatal: No such remote: '$name'");
          return;
        }
        return;
      }

      return;
    }

    for (var remote in repo.config.remotes) {
      if (!verbose!) {
        print(remote.name);
      } else {
        print('${remote.name}\t${remote.url} (fetch)');
        print('${remote.name}\t${remote.url} (push)');
      }
    }
  }
}
