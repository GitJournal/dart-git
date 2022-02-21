import 'dart:io';

import 'package:test/test.dart';

import 'package:dart_git/dart_git.dart';
import 'lib.dart';

void main() {
  late String gitDir;

  setUp(() async {
    gitDir = (await Directory.systemTemp.createTemp('_git_')).path;
    var _ = await cloneGittedFixture('mtime', gitDir);
  });

  test('Branch with a /', () {
    var repo = GitRepository.load(gitDir).getOrThrow();
    expect(repo.currentBranch().getOrThrow(), "master");

    repo.createBranch('hello/there').throwOnError();
    expect(repo.branches().getOrThrow()..sort(), ["hello/there", "master"]);

    repo.close().throwOnError();
  });
}
