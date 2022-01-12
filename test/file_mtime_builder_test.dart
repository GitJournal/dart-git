import 'dart:io';

import 'package:dart_git/plumbing/git_hash.dart';
import 'package:test/test.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/file_mtime_builder.dart';
import 'lib.dart';

/*
* commit 386de870a014e32234ce7f87e59a1beb06f720df (HEAD -> master)
| Author: Vishesh Handa <me@vhanda.in>
| Date:   Wed Jan 12 14:35:24 2022 +0100
|
|     Update 2.md
|
* commit b0a13aeafa9933dea95c06e0130e35c22dab816a
| Author: Vishesh Handa <me@vhanda.in>
| Date:   Wed Jan 12 14:34:01 2022 +0100
|
|     Update 1.md
|
* commit ded39800a9bd83c04a1f8cfd94c5003fe761a965
| Author: Vishesh Handa <me@vhanda.in>
| Date:   Wed Jan 12 14:33:01 2022 +0100
|
|     Create 2.md
|
* commit 1b8d6e92fd596ad31348ab9b8d1df5ebcac8cf0c
  Author: Vishesh Handa <me@vhanda.in>
  Date:   Wed Jan 12 14:32:19 2022 +0100

      Create 1.md
*/

void main() {
  late String gitDir;

  setUp(() async {
    gitDir = (await Directory.systemTemp.createTemp('_git_')).path;
    var _ = await cloneGittedFixture('mtime', gitDir);
  });

  test('Basic', () async {
    var repo = GitRepository.load(gitDir).getOrThrow();

    var tf = FileMTimeBuilder();
    repo
        .visitTree(
          fromCommitHash: GitHash('b0a13aeafa9933dea95c06e0130e35c22dab816a'),
          visitor: tf,
        )
        .throwOnError();

    expect(
      tf.mTime('1.md')!.toUtc().toIso8601String(),
      DateTime.parse('2022-01-12 14:34:01 +0100').toUtc().toIso8601String(),
    );
    expect(
      tf.mTime('2.md')!.toUtc().toIso8601String(),
      DateTime.parse('2022-01-12 14:33:01 +0100').toUtc().toIso8601String(),
    );

    repo
        .visitTree(
          fromCommitHash: GitHash('386de870a014e32234ce7f87e59a1beb06f720df'),
          visitor: tf,
        )
        .throwOnError();

    expect(
      tf.mTime('1.md')!.toUtc().toIso8601String(),
      DateTime.parse('2022-01-12 14:34:01 +0100').toUtc().toIso8601String(),
    );
    expect(
      tf.mTime('2.md')!.toUtc().toIso8601String(),
      DateTime.parse('2022-01-12 14:35:24 +0100').toUtc().toIso8601String(),
    );
  });
}

// FIXME: Do this for the dart-git repo
// FIXME: Test that file moves do not count as modifications
// FIXME: Test that deleted files are not in the cache
