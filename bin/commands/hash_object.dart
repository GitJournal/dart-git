// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';

class HashObjectCommand extends Command<int> {
  @override
  final name = 'hash-object';

  @override
  final description =
      'Compute object ID and optionally creates a blob from a file';

  final String currentDir;

  HashObjectCommand(this.currentDir) {
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
  int run() {
    if (argResults!.rest.isEmpty) {
      print('Must provide file path');
      return 1;
    }
    var filePath = argResults!.rest[0];
    if (!File(filePath).existsSync()) {
      filePath = p.join(currentDir, filePath);
    }
    var rawData = File(filePath).readAsBytesSync();
    var hash = GitHash.compute(rawData);

    var gitRootDir = GitRepository.findRootDir(currentDir)!;
    var repo = GitRepository.load(gitRootDir);

    var fmt = argResults!['type'] as String;
    var obj = createObject(ObjectTypes.getType(fmt), rawData, hash);
    var shouldWrite = argResults!['write'] as bool;
    if (shouldWrite) {
      repo.objStorage.writeObject(obj);
    }

    print(hash);
    return 0;
  }
}
