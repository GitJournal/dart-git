import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/file_mtime_builder.dart';
import 'package:dart_git/git.dart';

class MTimeBuilderCommand extends Command {
  @override
  final name = 'mTimeBuilder';

  @override
  final description = 'Internal Dart-Git tools';

  @override
  void run() {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = GitRepository.load(gitRootDir).getOrThrow();

    var builder = FileMTimeBuilder();
    var headHash = repo.headHash().getOrThrow();

    var stopwatch = Stopwatch()..start();
    repo.visitTree(fromCommitHash: headHash, visitor: builder).throwOnError();
    print("Building took: ${stopwatch.elapsed}");

    // builder.map.forEach((fp, info) {
    //   print('$fp -> ${info.dt} ${info.hash}');
    // });
  }
}
