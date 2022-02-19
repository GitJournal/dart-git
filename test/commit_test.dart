import 'dart:io';

import 'package:test/test.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'lib.dart';

void main() {
  test(
    'fixture mtime',
    () async => testFixture(
      'mtime',
      '386de870a014e32234ce7f87e59a1beb06f720df',
      '21d0abfb760ab8d62d293ff5a0e8ad87729d220b',
    ),
  );

  test(
    'fixture merge',
    () async => testFixture(
      'merge',
      'd377980616840997f6450f79c7b5f9701cf30ca3',
      'd1fd63822c1497e93bae52d2b65acbb613c573ac',
    ),
  );
}

Future<void> testFixture(String name, String headHash, String treeHash) async {
  var gitDir = Directory.systemTemp.createTempSync('_git_').path;
  var _ = await cloneGittedFixture(name, gitDir, GitHash(headHash));
  var repo = GitRepository.load(gitDir).getOrThrow();
  var index = repo.indexStorage.readIndex().getOrThrow();
  var treeH = repo.writeTree(index).getOrThrow();
  expect(treeH, GitHash(treeHash));

  repo.close().throwOnError();
}
