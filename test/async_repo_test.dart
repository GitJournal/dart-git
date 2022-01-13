import 'dart:io';

import 'package:test/test.dart';

import 'package:dart_git/git_async.dart';
import 'package:dart_git/plumbing/git_hash.dart';
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
    expect(await repo.headHash().getOrThrow(),
        GitHash('386de870a014e32234ce7f87e59a1beb06f720df'));

    repo.close();
  });
}
