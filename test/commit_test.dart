import 'dart:io';

import 'package:test/test.dart';

import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'lib.dart';

void main() {
  test('Commit all Initial Repo Test - Single File', () async {
    var tmpDir1 = (await Directory.systemTemp.createTemp('_git_real_')).path;
    var tmpDir2 = (await Directory.systemTemp.createTemp('_git_dart_')).path;

    print('Real Git: $tmpDir1');
    print('Dart Git: $tmpDir2');

    await runGitCommand('init .', tmpDir1);
    await GitRepository.init(tmpDir2);

    // Add the same file to both of them
    var contents = 'Hello there';
    await createFile(tmpDir1, 'hi.txt', contents);
    await createFile(tmpDir2, 'hi.txt', contents);

    // Do a git commit on both
    var date = DateTime(2020, 02, 15, 9, 8, 7);

    await runGitCommand('config user.name "Vishesh Handa"', tmpDir1);
    await runGitCommand('config user.email random@gmail.com', tmpDir1);
    await runGitCommand('add .', tmpDir1);
    await runGitCommand('commit -a -m "Message"', tmpDir1, env: {
      'GIT_AUTHOR_DATE': date.toIso8601String(),
      'GIT_COMMITTER_DATE': date.toIso8601String(),
    });

    var repo = await GitRepository.load(tmpDir2).get();
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

  test('Sort directories', () {
    var allDirs = [
      'test/plumbing/objects',
      'test/plumbing',
      'test/data',
      'test/commands',
      'test',
      'lib/storage',
      'lib/plumbing/objects',
      'lib/plumbing',
      'lib/commands',
      'lib',
      '.github/workflows',
      '.github',
      '',
    ];

    allDirs.sort(dirSortFunc);

    expect(allDirs.reversed.toList(), [
      'test/plumbing/objects',
      'lib/plumbing/objects',
      'test/plumbing',
      'test/data',
      'test/commands',
      'lib/storage',
      'lib/plumbing',
      'lib/commands',
      '.github/workflows',
      'test',
      'lib',
      '.github',
      '',
    ]);
  });
}
