import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:async/async.dart' show NullStreamSink;
import 'package:path/path.dart' as p;
import 'package:process_run/process_run.dart';
import 'package:process_run/shell.dart' as shell;
import 'package:test/test.dart';

import 'package:dart_git/config.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/utils/result.dart';
import '../bin/main.dart' as git;

var silenceShellOutput = true;

Future<String> runGitCommand(String command, String dir,
    {Map<String, String> env = const {}}) async {
  var sink = NullStreamSink<List<int>>();

  var results = await shell.run(
    'git $command',
    workingDirectory: dir,
    includeParentEnvironment: false,
    environment: env,
    throwOnError: false,
    // silence
    stdout: silenceShellOutput ? sink : null,
    stderr: silenceShellOutput ? sink : null,
  );

  var stdout = results.map((e) => e.stdout).join('\n').trim();
  var stderr = results.map((e) => e.stderr).join('\n').trim();

  return (stdout + '\n' + stderr).trim();
}

Future<void> createFile(String basePath, String path, String contents) async {
  var fullPath = p.join(basePath, path);

  await Directory(p.dirname(fullPath)).create(recursive: true);
  await File(fullPath).writeAsString(contents);
}

Future<void> testRepoEquals(String repo1, String repo2) async {
  if (!repo1.endsWith(p.separator)) {
    repo1 += p.separator;
  }
  if (!repo2.endsWith(p.separator)) {
    repo2 += p.separator;
  }

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

  var repo1Result =
      await runExecutableArguments('bash', [script], workingDirectory: repo1);
  var repo2Result =
      await runExecutableArguments('bash', [script], workingDirectory: repo2);

  var repo1Objects =
      repo1Result.stdout.split('\n').where((String e) => e.isNotEmpty).toSet();
  var repo2Objects =
      repo2Result.stdout.split('\n').where((String e) => e.isNotEmpty).toSet();

  expect(repo1Objects, repo2Objects);

  // Test if all the references are the same
  var listRefScript = 'git show-ref --head';
  script = p.join(Directory.systemTemp.path, 'list-refs');
  await File(script).writeAsString(listRefScript);

  repo1Result =
      await runExecutableArguments('bash', [script], workingDirectory: repo1);
  repo2Result =
      await runExecutableArguments('bash', [script], workingDirectory: repo2);

  var repo1Refs =
      repo1Result.stdout.split('\n').where((String e) => e.isNotEmpty).toSet();
  var repo2Refs =
      repo2Result.stdout.split('\n').where((String e) => e.isNotEmpty).toSet();

  expect(repo1Refs, repo2Refs);

  // Test if the index is the same
  var listIndexScript = 'git ls-files --stage';
  script = p.join(Directory.systemTemp.path, 'list-index');
  await File(script).writeAsString(listIndexScript);

  repo1Result =
      await runExecutableArguments('bash', [script], workingDirectory: repo1);
  repo2Result =
      await runExecutableArguments('bash', [script], workingDirectory: repo2);

  var repo1Index = repo1Result.stdout
      .split('\n')
      .where((String e) => e.isNotEmpty)
      .toSet() as Set<String>?;
  var repo2Index = repo2Result.stdout
      .split('\n')
      .where((String e) => e.isNotEmpty)
      .toSet() as Set<String>?;

  expect(repo1Index, repo2Index);

  // Test if the config is the same
  var config1Data = await File(p.join(repo1, '.git', 'config')).readAsString();
  var config2Data = await File(p.join(repo2, '.git', 'config')).readAsString();

  var config1 = ConfigFile.parse(config1Data);
  var config2 = ConfigFile.parse(config2Data);

  var c1 = config1.sections.where((s) => s.name != 'core' && s.name != 'user');
  var c2 = config2.sections.where((s) => s.name != 'core' && s.name != 'user');
  expect(c1, c2);

  // Test if the working dir is the same
  var repo1FsEntities = await Directory(repo1).list(recursive: true).toList();
  repo1FsEntities = repo1FsEntities
      .where((e) => !e.path.startsWith(p.join(repo1, '.git/')))
      .toList();
  var repo2FsEntities = await Directory(repo2).list(recursive: true).toList();
  repo2FsEntities = repo2FsEntities
      .where((e) => !e.path.startsWith(p.join(repo2, '.git/')))
      .toList();

  var repo1Files =
      repo1FsEntities.map((f) => f.path.substring(repo1.length)).toSet();
  var repo2Files =
      repo2FsEntities.map((f) => f.path.substring(repo2.length)).toSet();

  expect(repo1Files, repo2Files);

  for (var ent in repo1FsEntities) {
    var st = ent.statSync();
    if (st.type != FileSystemEntityType.file) {
      continue;
    }
    var path = ent.path.substring(repo1.length);
    var repo1FilePath = p.join(repo1, path);
    var repo2FilePath = p.join(repo2, path);

    try {
      var repo1File = await File(repo1FilePath).readAsString();
      var repo2File = await File(repo2FilePath).readAsString();

      expect(repo1File, repo2File, reason: '$path is different');
    } catch (e) {
      var repo1File = await File(repo1FilePath).readAsBytes();
      var repo2File = await File(repo2FilePath).readAsBytes();

      expect(repo1File, repo2File, reason: '$path is different');
    }
  }

  // FIXME:
  // Test if file/folder permissions are the same
}

Future<List<String>> runDartGitCommand(
    String command, String workingDir) async {
  var printLog = <String>[];

  if (!silenceShellOutput) {
    print('dartgit>\$ git $command');
  }

  var spec = ZoneSpecification(print: (_, __, ___, String msg) {
    printLog.add(msg);
  });
  await Zone.current.fork(specification: spec).run(() async {
    var prev = Directory.current;

    Directory.current = workingDir;
    // FIXME: There could be a space inside quotes
    try {
      await git.mainWithExitCode(command.split(' '));
    } catch (e) {
      printLog = ['$e'];
    }
    Directory.current = prev;
  });

  if (!silenceShellOutput) {
    for (var log in printLog) {
      print('dartgit>  $log');
    }
  }
  return printLog;
}

Future<void> copyDirectory(String source, String destination) async {
  await Directory(destination).create(recursive: true);
  await for (var entity in Directory(source).list(recursive: false)) {
    if (entity is Directory) {
      var newDirectory = Directory(p.join(
          Directory(destination).absolute.path, p.basename(entity.path)));
      await newDirectory.create();
      await copyDirectory(entity.absolute.path, newDirectory.path);
    } else if (entity is File) {
      await entity.copy(p.join(destination, p.basename(entity.path)));
    }
  }
}

Future<String> openFixture(String filePath) async {
  final bytes = await File(filePath).readAsBytes();
  final gzipBytes = GZipDecoder().decodeBytes(bytes);
  final archive = TarDecoder().decodeBytes(gzipBytes);

  var gitDir = (await Directory.systemTemp.createTemp()).path;
  var gitDotDir = p.join(gitDir, '.git');

  for (var file in archive) {
    var filename = file.name;
    if (file.isFile) {
      var data = file.content as List<int>;
      File(p.join(gitDotDir, filename))
        ..createSync(recursive: true)
        ..writeAsBytesSync(data);
    } else {
      await Directory(p.join(gitDotDir, filename)).create(recursive: true);
    }
  }

  return gitDir;
}

Future<String> cloneGittedFixture(String fixtureName, String newDirPath) async {
  var fixtureDirPath = 'test/data/$fixtureName';
  assert(Directory(fixtureDirPath).existsSync());
  assert(Directory('$fixtureDirPath/.gitted').existsSync());

  await copyDirectory(fixtureDirPath, newDirPath);
  assert(Directory('$newDirPath/.gitted').existsSync());
  await Directory('$newDirPath/.gitted').rename('$newDirPath/.git');
  print(newDirPath);
  print(Directory(newDirPath).path);

  return newDirPath;
}

extension GitStream on Stream<Result<GitCommit>> {
  Future<List<String>> asHashStrings() async {
    var list = <String>[];
    await for (var commitR in this) {
      var commit = commitR.getOrThrow();
      var hash = commit.hash.toString();
      list.add(hash);
    }
    return list;
  }
}
