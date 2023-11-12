import 'dart:io';

import 'package:test/test.dart';

import 'package:dart_git/git_async.dart';
import 'package:dart_git/plumbing/git_hash.dart';

import 'lib.dart';

void main() {
  late String gitDir;

  setUp(() async {
    gitDir = (await Directory.systemTemp.createTemp('_git_')).path;
    await cloneGittedFixture('mtime', gitDir);
  });

  test('Basic', () async {
    var repo = await GitAsyncRepository.load(gitDir);
    expect(await repo.currentBranch(), "master");
    expect(await repo.branches(), ["master"]);
    expect(await repo.headHash(),
        GitHash('386de870a014e32234ce7f87e59a1beb06f720df'));

    repo.close();
  });
}
