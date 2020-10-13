import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:process_run/process_run.dart';
import 'package:process_run/shell.dart' as shell;
import 'package:test/test.dart';

import 'package:dart_git/config.dart';
import 'package:dart_git/main.dart' as git;

Future<String> runGitCommand(String command, String dir,
    {Map<String, String> env = const {}}) async {
  var results = await shell.run(
    'git $command',
    workingDirectory: dir,
    includeParentEnvironment: false,
    commandVerbose: true,
    environment: env,
  );

  return results.map((e) => e.stdout).join('\n').trim();
}

Future<void> createFile(String basePath, String path, String contents) async {
  var fullPath = p.join(basePath, path);

  await Directory(p.basename(fullPath)).create(recursive: true);
  await File(fullPath).writeAsString(contents);
}

Future<void> testRepoEquals(String repo1, String repo2) async {
  // Test if all the objects are the same
  var listObjScript = r'''#!/bin/bash
set -e
shopt -s nullglob extglob

cd "`git rev-parse --git-path objects`"

# packed objects
for p in pack/pack-*([0-9a-f]).idx ; do
    git show-index < $p | cut -f 2 -d " "
done

# loose objects
for o in [0-9a-f][0-9a-f]/*([0-9a-f]) ; do
    echo ${o/\/}
done''';

  var script = p.join(Directory.systemTemp.path, 'list-objects');
  await File(script).writeAsString(listObjScript);

  var repo1Result = await run('bash', [script], workingDirectory: repo1);
  var repo2Result = await run('bash', [script], workingDirectory: repo2);

  var repo1Objects =
      repo1Result.stdout.split('\n').where((String e) => e.isNotEmpty).toSet();
  var repo2Objects =
      repo2Result.stdout.split('\n').where((String e) => e.isNotEmpty).toSet();

  expect(repo1Objects, repo2Objects);

  // Test if all the references are the same
  var listRefScript = 'git show-ref --head';
  script = p.join(Directory.systemTemp.path, 'list-refs');
  await File(script).writeAsString(listRefScript);

  repo1Result = await run('bash', [script], workingDirectory: repo1);
  repo2Result = await run('bash', [script], workingDirectory: repo2);

  var repo1Refs =
      repo1Result.stdout.split('\n').where((String e) => e.isNotEmpty).toSet();
  var repo2Refs =
      repo2Result.stdout.split('\n').where((String e) => e.isNotEmpty).toSet();

  expect(repo1Refs, repo2Refs);

  // Test if the config is the same
  var config1Data = await File(p.join(repo1, '.git', 'config')).readAsString();
  var config2Data = await File(p.join(repo2, '.git', 'config')).readAsString();

  var config1 = ConfigFile.parse(config1Data);
  var config2 = ConfigFile.parse(config2Data);

  var c1 = config1.sections.where((s) => s.name != 'core' && s.name != 'user');
  var c2 = config2.sections.where((s) => s.name != 'core' && s.name != 'user');
  expect(c1, c2);

  // Test if the index is the same
}

Future<List<String>> runDartGitCommand(
    String command, String workingDir) async {
  var printLog = <String>[];

  var spec = ZoneSpecification(print: (_, __, ___, String msg) {
    printLog.add(msg);
  });
  await Zone.current.fork(specification: spec).run(() async {
    var prev = Directory.current;

    Directory.current = workingDir;
    await git.main(command.split(' '));
    Directory.current = prev;
  });
  return printLog;
}
