import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';

class DumpIndexCommand extends Command {
  @override
  final name = 'dump-index';

  @override
  final description = 'Prints the contents of the .git/index';

  @override
  void run() {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = GitRepository.load(gitRootDir).getOrThrow();

    var index = repo.indexStorage.readIndex().getOrThrow();
    print('Index Version: ${index.versionNo}');
    for (var entry in index.entries) {
      var str = entry.toString();
      str = str.replaceAll(',', ',\n\t');
      str = str.replaceAll('{', '{\n\t');
      str = str.replaceAll('}', '\n}');
      print(str);
    }
  }
}
