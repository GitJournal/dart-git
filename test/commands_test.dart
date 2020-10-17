import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:process_run/shell.dart' as shell;
import 'package:test/test.dart';

import 'lib.dart';

void main() {
  String clonedGitDir;
  String tmpDir;

  String realGitDir;
  String dartGitDir;

  setUpAll(() async {
    tmpDir = (await Directory.systemTemp.createTemp('_git_')).path;

    var cloneUrl = 'https://github.com/GitJournal/dart_git.git';
    await runGitCommand('clone $cloneUrl', tmpDir);

    var repoName = p.basename(cloneUrl);
    if (cloneUrl.endsWith('.git')) {
      repoName = repoName.substring(0, repoName.lastIndexOf('.git'));
    }

    clonedGitDir = p.join(tmpDir, repoName);
    realGitDir = p.join(tmpDir, '${repoName}_git');
    dartGitDir = p.join(tmpDir, '${repoName}_dart');
  });

  setUp(() async {
    if (Directory(realGitDir).existsSync()) {
      await Directory(realGitDir).delete(recursive: true);
    }
    if (Directory(dartGitDir).existsSync()) {
      await Directory(dartGitDir).delete(recursive: true);
    }

    await Directory(realGitDir).create(recursive: true);
    await Directory(dartGitDir).create(recursive: true);

    await copyDirectory(clonedGitDir, realGitDir);
    await copyDirectory(clonedGitDir, dartGitDir);
  });

  Future<void> _testGitCommand(String command) async {
    var output = await runDartGitCommand(command, dartGitDir);
    var expectedOutput = await runGitCommand(command, realGitDir);

    expect(output.join('\n').trim(), expectedOutput);
    await testRepoEquals(realGitDir, dartGitDir);
  }

  Future<void> _testCommands(List<String> commands) async {
    for (var c in commands) {
      if (c.startsWith('git ')) {
        c = c.substring('git '.length);
        await _testGitCommand(c);
      } else {
        await shell.run(
          c,
          workingDirectory: dartGitDir,
          includeParentEnvironment: false,
        );

        await shell.run(
          c,
          workingDirectory: realGitDir,
          includeParentEnvironment: false,
        );
      }
    }
  }

  var singleCommandTests = [
    'branch',
    'branch test',
    'branch master',
    'branch -a',
    'write-tree',
    'remote',
    'remote -v',
    'rm LICENSE',
    'rm does-not-exist',
    'rm /outside-repo',
  ];

  for (var command in singleCommandTests) {
    test(command, () async => _testGitCommand(command));
  }

  test(
    'checkout 1 file',
    () async => _testCommands([
      'echo dddd > LICENSE',
      'git checkout LICENSE',
    ]),
  );

  test(
    'git rm deleted file',
    () async => _testCommands([
      'rm LICENSE',
      'git rm LICENSE',
    ]),
  );
}
