import 'dart:io';
import 'dart:convert';
import 'git.dart';
import 'commands/init.dart';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

void main(List<String> args) async {
  var runner = CommandRunner('git', 'Distributed version control.')
    ..addCommand(InitCommand());

  try {
    await runner.run(args);
  } catch (e) {
    print(e);
    return;
  }

  var parser = ArgParser();
  var catFileCommand = ArgParser();

  var hashObjectCommand = ArgParser();
  hashObjectCommand.addOption(
    'type',
    abbr: 't',
    defaultsTo: 'blob',
    allowed: ['blob', 'commit', 'tag', 'tree'],
    help: 'Specify the type',
  );
  hashObjectCommand.addFlag(
    'write',
    abbr: 'w',
    defaultsTo: true,
    help: 'Actually writes the object into the database',
  );

  parser.addCommand('cat-file', catFileCommand);
  parser.addCommand('hash-object', hashObjectCommand);

  var results = parser.parse(args);
  var cmd = results.command;
  if (cmd == null) {
    print(parser.usage);
    exit(0);
  }

  if (cmd.name == 'cat-file') {
    var repo = GitRepository(Directory.current.path);

    var objectSha1 = cmd.arguments[1];
    var obj = await repo.readObjectFromSha(objectSha1);
    if (obj is GitBlob) {
      var s = utf8.decode(obj.blobData);
      print(s);
    }
  }

  if (cmd.name == 'hash-object') {
    if (cmd.rest.isEmpty) {
      print('Must provide file path');
      return;
    }
    var filePath = cmd.rest[0];
    var rawData = File(filePath).readAsBytesSync();

    var repo = GitRepository(Directory.current.path);
    var fmt = cmd['type'] as String;
    var obj = repo.createObject(fmt, rawData);
    var sha1Hash = await repo.writeObject(obj, write: cmd['write']);
    print(sha1Hash);
  }
}
