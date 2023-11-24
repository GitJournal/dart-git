// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:process_run/shell.dart' as shell;
import 'package:test/test.dart';

import '../lib.dart';

class GitCommandSetupResult {
  late String clonedGitDir;
  late String tmpDir;

  late String realGitDir;
  late String dartGitDir;
}

Future<GitCommandSetupResult> gitCommandTestSetupAll() async {
  var result = GitCommandSetupResult();
  result.tmpDir = (await Directory.systemTemp.createTemp('_git_')).path;

  // Using the local file url doesn't work as not all branches will be copied
  var cloneUrl = 'https://github.com/GitJournal/dart_git.git';
  // var cloneUrl = 'file:///${Directory.current.path}';
  await runGitCommand(
    'clone $cloneUrl',
    result.tmpDir,
    throwOnError: true,
  );

  var repoName = p.basename(cloneUrl);
  if (repoName.endsWith('.git')) {
    repoName = repoName.substring(0, repoName.lastIndexOf('.git'));
  }

  result.clonedGitDir = p.join(result.tmpDir, repoName);
  result.realGitDir = p.join(result.tmpDir, '${repoName}_git');
  result.dartGitDir = p.join(result.tmpDir, '${repoName}_dart');

  if (!silenceShellOutput) {
    print('RealGitDir: ${result.realGitDir}');
    print('DartGitDir: ${result.dartGitDir}');
  }

/*
  var trackAllBranches = r"""#!/bin/bash
set -eu

for i in $(git branch -r | grep -vE 'HEAD|master' | sed 's/^[ ]\+//')
    do
      git checkout --track $i;
    done
    git checkout master
""";

  var script = p.join(Directory.systemTemp.path, 'trackAllBranches');
  File(script).writeAsStringSync(trackAllBranches);

  var sink = NullStreamSink<List<int>>();

  await shell.run(
    script,
    workingDirectory: result.clonedGitDir,
    includeParentEnvironment: false,
    throwOnError: true,
    runInShell: true,
    // silence
    stdout: silenceShellOutput ? sink : null,
    stderr: silenceShellOutput ? sink : null,
  );
  */

  return result;
}

Future<GitCommandSetupResult> gitCommandTestFixtureSetupAll(String name) async {
  var result = GitCommandSetupResult();
  result.tmpDir = (await Directory.systemTemp.createTemp('_git_')).path;

  result.clonedGitDir = p.join(result.tmpDir, name);
  result.realGitDir = p.join(result.tmpDir, '${name}_git');
  result.dartGitDir = p.join(result.tmpDir, '${name}_dart');

  await cloneGittedFixture(name, result.clonedGitDir);

  if (!silenceShellOutput) {
    print('RealGitDir: ${result.realGitDir}');
    print('DartGitDir: ${result.dartGitDir}');
  }

  return result;
}

Future<void> gitCommandTestSetup(GitCommandSetupResult r) async {
  if (Directory(r.realGitDir).existsSync()) {
    await Directory(r.realGitDir).delete(recursive: true);
  }
  if (Directory(r.dartGitDir).existsSync()) {
    await Directory(r.dartGitDir).delete(recursive: true);
  }

  await Directory(r.realGitDir).create(recursive: true);
  await Directory(r.dartGitDir).create(recursive: true);

  assert(Directory(r.clonedGitDir).existsSync());

  await copyDirectory(r.clonedGitDir, r.realGitDir);
  await copyDirectory(r.clonedGitDir, r.dartGitDir);
}

Future<void> testGitCommand(
  GitCommandSetupResult s,
  String command, {
  bool containsMatch = false,
  bool ignoreOutput = false,
  Map<String, String> env = const {},
  bool shouldReturnError = false,
}) async {
  // hack: Untill we implement git fetch
  var outputL = command.startsWith('fetch')
      ? (await runGitCommand(
          command,
          s.dartGitDir,
          env: env,
          shouldReturnError: shouldReturnError,
        ))
          .split('\n')
      : await runDartGitCommand(
          command,
          s.dartGitDir,
          env: env,
          shouldReturnError: shouldReturnError,
        );

  var output = outputL.join('\n').trim();
  var expectedOutput = await runGitCommand(
    command,
    s.realGitDir,
    env: env,
    shouldReturnError: shouldReturnError,
  );

  output = output.toLowerCase();
  expectedOutput = expectedOutput.toLowerCase();

  if (!ignoreOutput) {
    if (!containsMatch) {
      expect(output, expectedOutput);
    } else {
      expect(expectedOutput.contains(output), true);
    }
  }
  await testRepoEquals(s.dartGitDir, s.realGitDir);
}

Future<void> testCommands(
  GitCommandSetupResult s,
  List<String> commands, {
  bool emptyDirs = false,
  bool ignoreOutput = false,
}) async {
  if (emptyDirs) {
    await Directory(s.dartGitDir).delete(recursive: true);
    await Directory(s.realGitDir).delete(recursive: true);

    await Directory(s.dartGitDir).create();
    await Directory(s.realGitDir).create();
  }

  for (var c in commands) {
    if (c.startsWith('git ')) {
      c = c.substring('git '.length);
      await testGitCommand(s, c, ignoreOutput: ignoreOutput);
    } else {
      var sink = NullStreamSink<List<int>>();

      await shell.run(
        c,
        workingDirectory: s.dartGitDir,
        includeParentEnvironment: false,
        throwOnError: false,
        // silence
        stdout: silenceShellOutput ? sink : null,
        stderr: silenceShellOutput ? sink : null,
      );

      await shell.run(
        c,
        workingDirectory: s.realGitDir,
        includeParentEnvironment: false,
        throwOnError: false,
        // silence
        stdout: silenceShellOutput ? sink : null,
        stderr: silenceShellOutput ? sink : null,
      );
    }
  }
}
