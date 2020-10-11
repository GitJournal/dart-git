import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';

class CheckoutCommand extends Command {
  @override
  final name = 'checkout';

  @override
  final description = 'Switch branches or restore working tree files';

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path);
    var repo = await GitRepository.load(gitRootDir);

    if (argResults.arguments.isEmpty) {
      print('Must provide a file');
      return;
    }

    var filePath = argResults.arguments[0];

    var head = await repo.head();
    head = await repo.resolveReference(head);
    if (head.isHash == false) {
      print('WTF - Why is the head not a hash?');
    }

    var obj = await repo.readObjectFromHash(head.hash);
    var commit = obj as GitCommit;
    print('Got commit $commit');

    obj = await repo.readObjectFromHash(commit.treeHash);
    var tree = obj as GitTree;
    var i = tree.leaves.indexWhere((l) => l.path == filePath);
    if (i == -1) {
      print('File with path $filePath not found');
      return;
    }
    print('Got Tree $tree $i');

    obj = await repo.readObjectFromHash(tree.leaves[i].hash);
    if (obj is GitTree) {
      print('Only supports files for now');
      return;
    }

    var blob = obj as GitBlob;
    await File(filePath).writeAsBytes(blob.blobData);
    print('Updated 1 path from the index');
  }
}
