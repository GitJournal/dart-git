import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_git/git.dart';
import 'package:dart_git/git_hash.dart';

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
    if (argResults.rest.isEmpty) {
      print('Must provide file path');
      return;
    }
    var filePath = argResults.rest[0];
    var rawData = File(filePath).readAsBytesSync();

    var repo = GitRepository(Directory.current.path);
    var fmt = argResults['type'] as String;
    var obj = createObject(fmt, rawData);
    GitHash hash;
    if (argResults['write']) {
      hash = await repo.writeObject(obj);
    } else {
      hash = obj.hash();
    }
    print(hash);
  }
}
