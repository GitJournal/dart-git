import 'dart:io';

import 'package:test/test.dart';

import 'package:dart_git/git_async.dart';
import 'package:dart_git/utils/result.dart';

import 'lib.dart';

void main() {
  late String gitDir;

  setUp(() async {
    gitDir = (await Directory.systemTemp.createTemp('_git_')).path;
    var _ = await cloneGittedFixture('mtime', gitDir);
  });

  test('Basic', () async {
    var repo = await GitAsyncRepository.load(gitDir).getOrThrow();
    expect(await repo.currentBranch().getOrThrow(), "master");
    expect(await repo.branches().getOrThrow(), ["master"]);

    repo.close();
  });
}
