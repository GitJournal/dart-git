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

  var cloneUrl = 'https://github.com/GitJournal/dart_git.git';
  var _ = await runGitCommand('clone $cloneUrl', result.tmpDir);

  var repoName = p.basename(cloneUrl);
  if (cloneUrl.endsWith('.git')) {
    repoName = repoName.substring(0, repoName.lastIndexOf('.git'));
  }

  result.clonedGitDir = p.join(result.tmpDir, repoName);
  result.realGitDir = p.join(result.tmpDir, '${repoName}_git');
  result.dartGitDir = p.join(result.tmpDir, '${repoName}_dart');

  if (!silenceShellOutput) {
    print('RealGitDir: ${result.realGitDir}');
    print('DartGitDir: ${result.dartGitDir}');
  }

  return result;
}

Future<GitCommandSetupResult> gitCommandTestFixtureSetupAll(String name) async {
  var result = GitCommandSetupResult();
  result.tmpDir = (await Directory.systemTemp.createTemp('_git_')).path;

  result.clonedGitDir = p.join(result.tmpDir, name);
  result.realGitDir = p.join(result.tmpDir, '${name}_git');
  result.dartGitDir = p.join(result.tmpDir, '${name}_dart');

  var _ = await cloneGittedFixture(name, result.clonedGitDir);

  if (!silenceShellOutput) {
    print('RealGitDir: ${result.realGitDir}');
    print('DartGitDir: ${result.dartGitDir}');
  }

  return result;
}

Future<void> gitCommandTestSetup(GitCommandSetupResult r) async {
  if (Directory(r.realGitDir).existsSync()) {
    var _ = await Directory(r.realGitDir).delete(recursive: true);
  }
  if (Directory(r.dartGitDir).existsSync()) {
    var _ = await Directory(r.dartGitDir).delete(recursive: true);
  }

  var _ = await Directory(r.realGitDir).create(recursive: true);
  var __ = await Directory(r.dartGitDir).create(recursive: true);

  await copyDirectory(r.clonedGitDir, r.realGitDir);
  await copyDirectory(r.clonedGitDir, r.dartGitDir);

  // print('r.realGitDir: $realGitDir');
  // print('r.dartGitDir: $dartGitDir');
}

Future<void> testGitCommand(
  GitCommandSetupResult s,
  String command, {
  bool containsMatch = false,
  bool ignoreOutput = false,
  Map<String, String> env = const {},
}) async {
  // hack: Untill we implement git fetch
  var outputL = command.startsWith('fetch')
      ? (await runGitCommand(command, s.dartGitDir, env: env)).split('\n')
      : await runDartGitCommand(command, s.dartGitDir, env: env);
  var output = outputL.join('\n').trim();
  var expectedOutput = await runGitCommand(command, s.realGitDir, env: env);

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
    dynamic _;
    _ = await Directory(s.dartGitDir).delete(recursive: true);
    _ = await Directory(s.realGitDir).delete(recursive: true);

    _ = await Directory(s.dartGitDir).create();
    _ = await Directory(s.realGitDir).create();
  }

  for (var c in commands) {
    if (c.startsWith('git ')) {
      c = c.substring('git '.length);
      await testGitCommand(s, c, ignoreOutput: ignoreOutput);
    } else {
      var sink = NullStreamSink<List<int>>();

      dynamic _;
      _ = await shell.run(
        c,
        workingDirectory: s.dartGitDir,
        includeParentEnvironment: false,
        throwOnError: false,
        // silence
        stdout: silenceShellOutput ? sink : null,
        stderr: silenceShellOutput ? sink : null,
      );

      _ = await shell.run(
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
