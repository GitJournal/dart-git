import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_git/git.dart';

class LsTreeCommand extends Command {
  @override
  final name = 'ls-tree';

  @override
  final description = 'List the contents of a tree object';

  @override
  Future run() async {
    var objectSha1 = argResults.rest.first;

    var repo = GitRepository(Directory.current.path);
    var obj = await repo.readObjectFromSha(objectSha1);
    assert(obj is GitTree);

    var tree = obj as GitTree;
    for (var leaf in tree.leaves) {
      var leafObj = await repo.readObjectFromSha(leaf.sha);
      var type = ascii.decode(leafObj.format());
      print('${leaf.mode.padLeft(6, '0')} $type ${leaf.sha}    ${leaf.path}');
    }
  }
}
