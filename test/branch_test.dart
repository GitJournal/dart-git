import 'dart:io';

import 'package:test/test.dart';

import 'package:dart_git/dart_git.dart';
import 'lib.dart';

void main() {
  late String gitDir;

  setUp(() async {
    gitDir = (await Directory.systemTemp.createTemp('_git_')).path;
    await cloneGittedFixture('mtime', gitDir);
  });

  test('Branch with a /', () {
    var repo = GitRepository.load(gitDir);
    expect(repo.currentBranch(), "master");

    repo.createBranch('hello/there');
    expect(repo.branches()..sort(), ["hello/there", "master"]);

    repo.close();
  });
}
