import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_git/git.dart';

class StatusCommand extends Command {
  @override
  final name = 'status';

  @override
  final description = 'Show the working tree status';

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path);
    var repo = await GitRepository.load(gitRootDir);

    var head = await repo.head();
    if (head.isHash) {
      print('HEAD detached at ${head.hash}');
    } else {
      print('On branch ${head.target.branchName()}');
    }
  }
}
