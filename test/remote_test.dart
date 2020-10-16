import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:dart_git/git.dart';
import 'lib.dart';

void main() {
  test('Clone - Remote Head', () async {
    var tmpDir = (await Directory.systemTemp.createTemp('_git_')).path;

    await runGitCommand('clone https://github.com/vHanda/test_gj.git', tmpDir);
    var gitDir = p.join(tmpDir, 'test_gj');

    var repo = await GitRepository.load(gitDir);
    var remoteBranch = await repo.guessRemoteHead('origin');

    expect(remoteBranch.name.branchName(), 'dev');
  });

  test('Fetch - Remote Head', () async {
    var gitDir = (await Directory.systemTemp.createTemp('_git_fetch_')).path;

    await runGitCommand('init .', gitDir);
    await runGitCommand(
        'remote add origin https://github.com/vHanda/test_gj.git', gitDir);
    await runGitCommand('fetch origin', gitDir);

    var repo = await GitRepository.load(gitDir);
    var remoteBranch = await repo.guessRemoteHead('origin');

    expect(remoteBranch.name.branchName(), 'dev');
  });
}
