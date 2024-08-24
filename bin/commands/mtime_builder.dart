// ignore_for_file: avoid_print

import 'package:args/command_runner.dart';

import 'package:dart_git/file_mtime_builder.dart';
import 'package:dart_git/git.dart';

class MTimeBuilderCommand extends Command<int> {
  @override
  final name = 'mTimeBuilder';

  @override
  final description = 'Internal Dart-Git tools';

  final String currentDir;

  MTimeBuilderCommand(this.currentDir) {
    argParser.addFlag('debug', abbr: 'd', defaultsTo: false);
  }

  @override
  int run() {
    var gitRootDir = GitRepository.findRootDir(currentDir)!;
    var repo = GitRepository.load(gitRootDir);

    var builder = FileMTimeBuilder();
    var headHash = repo.headHash();

    var stopwatch = Stopwatch()..start();
    repo.visitTree(fromCommitHash: headHash, visitor: builder);
    print("Building took: ${stopwatch.elapsed}");

    if (argResults!['debug'] == true) {
      builder.map.forEach((fp, info) {
        print('$fp -> ${info.dt} ${info.hash}');
      });
    }

    return 0;
  }
}
