// Code Adapated from go-git commit_walker_bfs_filtered_test.go

import 'package:test/test.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/commit_iterator.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/storage/interfaces.dart';
import '../lib.dart';

/*
// TestCase history

* 6ecf0ef2c2dffb796033e5a02219af86ec6584e5 <- HEAD
|
| * e8d3ffab552895c19b9fcf7aa264d277cde33881
|/
* 918c48b83bd081e863dbe1b80f8998f058cd8294
|
* af2d6a6954d532f8ffb47615169c8fdf9d383a1a
|
* 1669dce138d9b841a518c64b10914d88f5e488ea
|\
| * a5b8b09e2f8fcb0bb99d3ccb0958157b40890d69	// isLimit
| |\
| | * b8e471f58bcbca63b07bda20e428190409c2db47  // ignored if isLimit is passed
| |/
* | 35e85108805c84807bc66a02d91535e1e24b38b9	// isValid
|/
* b029517f6300c2da0f4b651b8642506cd6aaf45d
*/

void main() {
  String gitDir;
  late ObjectStorage objStorage;
  late GitHash headHash;

  setUpAll(() async {
    gitDir = await openFixture(
        'test/data/git-7a725350b88b05ca03541b59dd0649fda7f521f2.tgz');

    var repo = await GitRepository.load(gitDir).getOrThrow();
    objStorage = repo.objStorage;
    headHash = await repo.headHash().getOrThrow();
  });

  /// We should get all commits from the history but,
  /// e8d3ffab552895c19b9fcf7aa264d277cde33881, that is not reachable from HEAD
  test('Basic', () async {
    var iter = commitIteratorBFSFiltered(
      objStorage: objStorage,
      from: headHash,
    );

    var expected = <String>[
      '6ecf0ef2c2dffb796033e5a02219af86ec6584e5',
      '918c48b83bd081e863dbe1b80f8998f058cd8294',
      'af2d6a6954d532f8ffb47615169c8fdf9d383a1a',
      '1669dce138d9b841a518c64b10914d88f5e488ea',
      '35e85108805c84807bc66a02d91535e1e24b38b9',
      'a5b8b09e2f8fcb0bb99d3ccb0958157b40890d69',
      'b029517f6300c2da0f4b651b8642506cd6aaf45d',
      'b8e471f58bcbca63b07bda20e428190409c2db47',
    ];

    expect(await iter.asHashStrings(), expected);
  });

  test('Filter All But One', () async {
    var iter = commitIteratorBFSFiltered(
      objStorage: objStorage,
      from: headHash,
      isValid: (commit) =>
          commit.hash == GitHash('35e85108805c84807bc66a02d91535e1e24b38b9'),
    );

    var expected = <String>[
      '35e85108805c84807bc66a02d91535e1e24b38b9',
    ];

    expect(await iter.asHashStrings(), expected);
  });

  test('Filter All', () async {
    var iter = commitIteratorBFSFiltered(
      objStorage: objStorage,
      from: headHash,
      isValid: (commit) => commit.hash == GitHash.zero(),
    );

    expect(await iter.asHashStrings(), []);
  });

  test('isLimit', () async {
    var iter = commitIteratorBFSFiltered(
      objStorage: objStorage,
      from: headHash,
      isLimit: (commit) =>
          commit.hash == GitHash('a5b8b09e2f8fcb0bb99d3ccb0958157b40890d69'),
    );

    var expected = <String>[
      '6ecf0ef2c2dffb796033e5a02219af86ec6584e5',
      '918c48b83bd081e863dbe1b80f8998f058cd8294',
      'af2d6a6954d532f8ffb47615169c8fdf9d383a1a',
      '1669dce138d9b841a518c64b10914d88f5e488ea',
      '35e85108805c84807bc66a02d91535e1e24b38b9',
      'a5b8b09e2f8fcb0bb99d3ccb0958157b40890d69',
      'b029517f6300c2da0f4b651b8642506cd6aaf45d',
    ];

    expect(await iter.asHashStrings(), expected);
  });

  test('isValid and isLimit', () async {
    var iter = commitIteratorBFSFiltered(
      objStorage: objStorage,
      from: headHash,
      isValid: (commit) =>
          commit.hash != GitHash('35e85108805c84807bc66a02d91535e1e24b38b9'),
      isLimit: (commit) =>
          commit.hash == GitHash('a5b8b09e2f8fcb0bb99d3ccb0958157b40890d69'),
    );

    var expected = <String>[
      '6ecf0ef2c2dffb796033e5a02219af86ec6584e5',
      '918c48b83bd081e863dbe1b80f8998f058cd8294',
      'af2d6a6954d532f8ffb47615169c8fdf9d383a1a',
      '1669dce138d9b841a518c64b10914d88f5e488ea',
      'a5b8b09e2f8fcb0bb99d3ccb0958157b40890d69',
      'b029517f6300c2da0f4b651b8642506cd6aaf45d',
    ];

    expect(await iter.asHashStrings(), expected);
  });
}
