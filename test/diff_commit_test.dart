import 'dart:io';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/diff_commit.dart';
import 'package:test/test.dart';

import 'package:dart_git/plumbing/git_hash.dart';
import 'lib.dart';

void main() {
  late String gitDir;

  setUp(() async {
    gitDir = (await Directory.systemTemp.createTemp()).path;
    var _ = await cloneGittedFixture('diff-commits-1', gitDir);
  });

  test('Duplicate Tree Object', () {
    var repo = GitRepository.load(gitDir).getOrThrow();

    var headH = GitHash('c159d088a2336b02628053b5cc12f35caba4ad40');
    var firstH = GitHash('7abde5fb8f1773728f711d237595233c299628a3');

    var head = repo.objStorage.readCommit(headH).getOrThrow();
    var first = repo.objStorage.readCommit(firstH).getOrThrow();

    var r = diffCommits(
      fromCommit: first,
      toCommit: head,
      objStore: repo.objStorage,
    );
    expect(r.error, null);

    var changes = r.getOrThrow();
    expect(changes.add.length, 2);
    expect(changes.remove.length, 0);
    expect(changes.modify.length, 0);

    var c1 = changes.add[0];
    var c2 = changes.add[1];
    expect(c1.hash, c2.hash);
    expect(c1.hash, GitHash('0cfbf08886fca9a91cb753ec8734c84fcbe52c9f'));
    expect(c1.path, isNot(c2.path));

    var _ = repo.close();
  });
}
