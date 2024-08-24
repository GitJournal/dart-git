// ignore_for_file: avoid_print

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';

class DumpIndexCommand extends Command<int> {
  @override
  final name = 'dump-index';

  @override
  final description = 'Prints the contents of the .git/index';

  final String currentDir;

  DumpIndexCommand(this.currentDir);

  @override
  int run() {
    var gitRootDir = GitRepository.findRootDir(currentDir)!;
    var repo = GitRepository.load(gitRootDir);

    var index = repo.indexStorage.readIndex();
    print('Index Version: ${index.versionNo}');
    for (var entry in index.entries) {
      var str = entry.toString();
      str = str.replaceAll(',', ',\n\t');
      str = str.replaceAll('{', '{\n\t');
      str = str.replaceAll('}', '\n}');
      print(str);
    }

    return 0;
  }
}
