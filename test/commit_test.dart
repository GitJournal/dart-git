import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:process_run/process_run.dart';
import 'package:process_run/shell.dart' as shell;
import 'package:test/test.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/objects/commit.dart';

void main() {
  test('Commit all Initial Repo Test - Single File', () async {
    var tmpDir1 = (await Directory.systemTemp.createTemp('_git_real_')).path;
    var tmpDir2 = (await Directory.systemTemp.createTemp('_git_dart_')).path;

    print('Real Git: $tmpDir1');
    print('Dart Git: $tmpDir2');

    await runGitCommand(tmpDir1, 'init .');
    await GitRepository.init(tmpDir2);

    // Add the same file to both of them
    var contents = 'Hello there';
    await createFile(tmpDir1, 'hi.txt', contents);
    await createFile(tmpDir2, 'hi.txt', contents);

    // Do a git commit on both
    var date = DateTime(2020, 02, 15, 9, 8, 7);

    await runGitCommand(tmpDir1, 'config user.name "Vishesh Handa"');
    await runGitCommand(tmpDir1, 'config user.email random@gmail.com');
    await runGitCommand(tmpDir1, 'add .');
    await runGitCommand(tmpDir1, 'commit -a -m "Message"', env: {
      'GIT_AUTHOR_DATE': date.toIso8601String(),
      'GIT_COMMITTER_DATE': date.toIso8601String(),
    });

    var repo = await GitRepository.load(tmpDir2);
    await repo.commit(
      message: 'Message\n',
      author: GitAuthor(
        name: 'Vishesh Handa',
        email: 'random@gmail.com',
        date: date,
      ),
      addAll: true,
    );

    // Do a comparison
    await testRepoEquals(tmpDir2, tmpDir1);
  });
}

Future<void> runGitCommand(String dir, String command,
    {Map<String, String> env = const {}}) async {
  await shell.run(
    'git $command',
    workingDirectory: dir,
    includeParentEnvironment: false,
    commandVerbose: true,
    environment: env,
  );
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

  //repo1Objects.sort();
  //repo2Objects.sort();

  expect(repo1Objects, repo2Objects);

  // Test if the index is the same

  // Test if all the references are the same
}
