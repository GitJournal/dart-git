import 'dart:io';

import 'package:test/test.dart';

import 'package:dart_git/blob_ctime_builder.dart';
import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/utils/date_time.dart';
import 'lib.dart';

void main() {
  late String gitDir;

  setUp(() async {
    gitDir = (await Directory.systemTemp.createTemp('_git_')).path;
    await cloneGittedFixture('merge', gitDir);
  });

  test('Basic', () async {
    var repo = GitRepository.load(gitDir);

    var tf = BlobCTimeBuilder();
    repo.visitTree(
      fromCommitHash: repo.headHash(),
      visitor: tf,
    );

    var offset = const Duration(hours: 2);
    expect(
      tf.cTime(GitHash('12232253399c1483f1b8ef1488eb69be155aa2e8')),
      GDateTime.fromTimeStamp(offset, 1623404188),
    );
    expect(
      tf.cTime(GitHash('7bd3fe09293186894615a396e9f6de27241a1e09')),
      GDateTime.fromTimeStamp(offset, 1623404188),
    );
    expect(
      tf.cTime(GitHash('8829dffa4881a4f914cb181f20364f545f785ad6')),
      GDateTime.fromTimeStamp(offset, 1623403876),
    );
    expect(
      tf.cTime(GitHash('ab266b8d4c463a70f5b543c9f58494970ebecd32')),
      GDateTime.fromTimeStamp(offset, 1623403961),
    );
  });
}

// FIXME: Do this for the dart-git repo
