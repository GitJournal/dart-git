import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';

class HashObjectCommand extends Command {
  @override
  final name = 'hash-object';

  @override
  final description =
      'Compute object ID and optionally creates a blob from a file';

  HashObjectCommand() {
    argParser.addOption(
      'type',
      abbr: 't',
      defaultsTo: 'blob',
      allowed: ['blob', 'commit', 'tag', 'tree'],
      help: 'Specify the type',
    );
    argParser.addFlag(
      'write',
      abbr: 'w',
      defaultsTo: true,
      help: 'Actually writes the object into the database',
    );
  }

  @override
  Future run() async {
    if (argResults!.rest.isEmpty) {
      print('Must provide file path');
      return;
    }
    var filePath = argResults!.rest[0];
    var rawData = File(filePath).readAsBytesSync();

    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = await GitRepository.load(gitRootDir).get();

    var fmt = argResults!['type'] as String;
    var objRes = createObject(fmt, rawData);
    var obj = objRes.get();
    GitHash hash;
    if (argResults!['write'] as bool) {
      hash = await repo.objStorage.writeObject(obj);
    } else {
      hash = obj.hash;
    }
    print(hash);
  }
}
