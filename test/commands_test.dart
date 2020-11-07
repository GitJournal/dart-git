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

    print('RealGitDir: $realGitDir');
    print('DartGitDir: $dartGitDir');
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

    // print('realGitDir: $realGitDir');
    // print('dartGitDir: $dartGitDir');
  });

  Future<void> _testGitCommand(String command) async {
    var output = <String>[];
    // hack: Untill we implement git fetch
    if (command.startsWith('fetch')) {
      output = (await runGitCommand(command, dartGitDir)).split('\n');
    } else {
      output = await runDartGitCommand(command, dartGitDir);
    }
    var expectedOutput = await runGitCommand(command, realGitDir);

    expect(output.join('\n').trim(), expectedOutput);
    await testRepoEquals(dartGitDir, realGitDir);
  }

  Future<void> _testCommands(
    List<String> commands, {
    bool emptyDirs = false,
  }) async {
    if (emptyDirs) {
      await Directory(dartGitDir).delete(recursive: true);
      await Directory(realGitDir).delete(recursive: true);

      await Directory(dartGitDir).create();
      await Directory(realGitDir).create();
    }

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
    'rm LICENSE',
    'rm does-not-exist',
    'rm /outside-repo',
    'branch -d not-existing'
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

  test(
    'git delete branch',
    () async => _testCommands([
      'git branch foo',
      'git branch -d foo',
    ]),
  );

  test(
    'git upstream branch',
    () async => _testCommands([
      'git branch foo/fde',
      'git branch --set-upstream-to=origin/master',
    ]),
  );

  test(
    'git remote',
    () async => _testCommands([
      'git remote add origin2 foo',
      'git remote',
      'git remote -v',
      'git remote rm origin2'
    ]),
  );

  test(
    'git checkout remote branch',
    () async => _testCommands([
      'git init -q .',
      'git remote add origin https://github.com/GitJournal/icloud_documents_path.git',
      'git fetch origin',
      'git checkout -b master origin/master',
      'git remote rm origin',
    ], emptyDirs: true),
  );
}
