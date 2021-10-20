import 'dart:io';

import 'package:dart_git/file_mtime_builder.dart';
import 'package:test/test.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/utils/date_time_tz_offset.dart';
import 'lib.dart';

void main() {
  late String gitDir;

  setUp(() async {
    gitDir = (await Directory.systemTemp.createTemp('_git_')).path;
    var _ = await cloneGittedFixture('merge', gitDir);
  });

  test('Basic', () async {
    var repo = await GitRepository.load(gitDir).getOrThrow();

    var tf = FileMTimeBuilder(repo);
    await tf.build(from: await repo.headCommit().getOrThrow()).throwOnError();

    expect(
      tf.mTime('1.md')!.toUtc().toIso8601String(),
      DateTime.parse('2021-06-11 11:36:28 +0200').toUtc().toIso8601String(),
    );
    expect(
      tf.mTime('2.md')!.toUtc().toIso8601String(),
      DateTime.parse('2021-06-11 11:36:28 +0200').toUtc().toIso8601String(),
    );
  });
}

// FIXME: Do this for the dart-git repo
// FIXME: Test that file moves do not count as modifications
