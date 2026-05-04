import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:dart_git/dart_git.dart';

import 'lib.dart';

void main() {
  test('fast-forward merge preserves unstaged working tree deletion', () async {
    var gitDir = await Directory.systemTemp.createTemp('_git_');

    await runGitCommand('init -b master', gitDir.path);
    await runGitCommand('config user.name "Test User"', gitDir.path);
    await runGitCommand('config user.email test@example.com', gitDir.path);

    createFile(gitDir.path, 'keep.md', 'keep');
    createFile(gitDir.path, 'deleted.md', 'gone');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m initial', gitDir.path);

    await runGitCommand('checkout -b remote', gitDir.path);
    createFile(gitDir.path, 'keep.md', 'updated');
    await runGitCommand('commit -am update', gitDir.path);

    await runGitCommand('checkout master', gitDir.path);
    File(p.join(gitDir.path, 'deleted.md')).deleteSync();

    var repo = GitRepository.load(gitDir.path);
    addTearDown(repo.close);

    var theirCommit = repo.branchCommit('remote')!;
    repo.merge(
      theirCommit: theirCommit,
      message: 'Merge remote',
      author: GitAuthor(
        name: 'Test User',
        email: 'test@example.com',
      ),
    );

    expect(
      File(p.join(gitDir.path, 'deleted.md')).existsSync(),
      isFalse,
      reason: 'A fast-forward merge must not recreate an unstaged deletion.',
    );
  });

  test('merge commit preserves unstaged working tree deletion', () async {
    var gitDir = await Directory.systemTemp.createTemp('_git_');

    await runGitCommand('init -b master', gitDir.path);
    await runGitCommand('config user.name "Test User"', gitDir.path);
    await runGitCommand('config user.email test@example.com', gitDir.path);

    createFile(gitDir.path, 'keep.md', 'keep');
    createFile(gitDir.path, 'deleted.md', 'gone');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m initial', gitDir.path);

    await runGitCommand('checkout -b remote', gitDir.path);
    createFile(gitDir.path, 'keep.md', 'updated');
    await runGitCommand('commit -am update', gitDir.path);

    await runGitCommand('checkout master', gitDir.path);
    createFile(gitDir.path, 'local.md', 'local');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m local', gitDir.path);
    File(p.join(gitDir.path, 'deleted.md')).deleteSync();

    var repo = GitRepository.load(gitDir.path);
    addTearDown(repo.close);

    var theirCommit = repo.branchCommit('remote')!;
    repo.merge(
      theirCommit: theirCommit,
      message: 'Merge remote',
      author: GitAuthor(
        name: 'Test User',
        email: 'test@example.com',
      ),
    );

    expect(
      File(p.join(gitDir.path, 'deleted.md')).existsSync(),
      isFalse,
      reason: 'A merge commit must not recreate an unstaged deletion.',
    );
  });

  test('fast-forward merge applies remote deletion', () async {
    var gitDir = await Directory.systemTemp.createTemp('_git_');

    await runGitCommand('init -b master', gitDir.path);
    await runGitCommand('config user.name "Test User"', gitDir.path);
    await runGitCommand('config user.email test@example.com', gitDir.path);

    createFile(gitDir.path, 'keep.md', 'keep');
    createFile(gitDir.path, 'deleted.md', 'gone');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m initial', gitDir.path);

    await runGitCommand('checkout -b remote', gitDir.path);
    File(p.join(gitDir.path, 'deleted.md')).deleteSync();
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m delete-file', gitDir.path);

    await runGitCommand('checkout master', gitDir.path);

    var repo = GitRepository.load(gitDir.path);
    addTearDown(repo.close);

    var theirCommit = repo.branchCommit('remote')!;
    repo.merge(
      theirCommit: theirCommit,
      message: 'Merge remote',
      author: GitAuthor(
        name: 'Test User',
        email: 'test@example.com',
      ),
    );

    expect(
      File(p.join(gitDir.path, 'deleted.md')).existsSync(),
      isFalse,
      reason: 'A fast-forward merge must apply deletions from the remote.',
    );
  });

  test('merge commit applies remote deletion', () async {
    var gitDir = await Directory.systemTemp.createTemp('_git_');

    await runGitCommand('init -b master', gitDir.path);
    await runGitCommand('config user.name "Test User"', gitDir.path);
    await runGitCommand('config user.email test@example.com', gitDir.path);

    createFile(gitDir.path, 'keep.md', 'keep');
    createFile(gitDir.path, 'deleted.md', 'gone');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m initial', gitDir.path);

    await runGitCommand('checkout -b remote', gitDir.path);
    File(p.join(gitDir.path, 'deleted.md')).deleteSync();
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m delete-file', gitDir.path);

    await runGitCommand('checkout master', gitDir.path);
    createFile(gitDir.path, 'local.md', 'local');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m local', gitDir.path);

    var repo = GitRepository.load(gitDir.path);
    addTearDown(repo.close);

    var theirCommit = repo.branchCommit('remote')!;
    repo.merge(
      theirCommit: theirCommit,
      message: 'Merge remote',
      author: GitAuthor(
        name: 'Test User',
        email: 'test@example.com',
      ),
    );

    expect(
      File(p.join(gitDir.path, 'deleted.md')).existsSync(),
      isFalse,
      reason: 'A merge commit must apply deletions from the remote.',
    );
  });

  test('fast-forward merge applies remote addition and modification', () async {
    var gitDir = await Directory.systemTemp.createTemp('_git_');
    await _initRepo(gitDir);

    createFile(gitDir.path, 'modified.md', 'base');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m initial', gitDir.path);

    await runGitCommand('checkout -b remote', gitDir.path);
    createFile(gitDir.path, 'modified.md', 'remote');
    createFile(gitDir.path, 'remote.md', 'remote-add');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m remote-change', gitDir.path);

    await runGitCommand('checkout master', gitDir.path);
    await _mergeRemote(gitDir);

    expect(
        File(p.join(gitDir.path, 'modified.md')).readAsStringSync(), 'remote');
    expect(File(p.join(gitDir.path, 'remote.md')).readAsStringSync(),
        'remote-add');
  });

  test('merge commit applies remote-only modification', () async {
    var gitDir = await Directory.systemTemp.createTemp('_git_');
    await _initRepo(gitDir);

    createFile(gitDir.path, 'modified.md', 'base');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m initial', gitDir.path);

    await runGitCommand('checkout -b remote', gitDir.path);
    createFile(gitDir.path, 'modified.md', 'remote');
    await runGitCommand('commit -am remote-change', gitDir.path);

    await runGitCommand('checkout master', gitDir.path);
    createFile(gitDir.path, 'local.md', 'local');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m local-change', gitDir.path);

    await _mergeRemote(gitDir);

    expect(
        File(p.join(gitDir.path, 'modified.md')).readAsStringSync(), 'remote');
    expect(File(p.join(gitDir.path, 'local.md')).readAsStringSync(), 'local');
  });

  test('merge commit keeps local-only modification', () async {
    var gitDir = await Directory.systemTemp.createTemp('_git_');
    await _initRepo(gitDir);

    createFile(gitDir.path, 'modified.md', 'base');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m initial', gitDir.path);

    await runGitCommand('checkout -b remote', gitDir.path);
    createFile(gitDir.path, 'remote.md', 'remote');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m remote-change', gitDir.path);

    await runGitCommand('checkout master', gitDir.path);
    createFile(gitDir.path, 'modified.md', 'local');
    await runGitCommand('commit -am local-change', gitDir.path);

    await _mergeRemote(gitDir);

    expect(
        File(p.join(gitDir.path, 'modified.md')).readAsStringSync(), 'local');
    expect(File(p.join(gitDir.path, 'remote.md')).readAsStringSync(), 'remote');
  });

  test('merge commit keeps local-only deletion', () async {
    var gitDir = await Directory.systemTemp.createTemp('_git_');
    await _initRepo(gitDir);

    createFile(gitDir.path, 'deleted.md', 'base');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m initial', gitDir.path);

    await runGitCommand('checkout -b remote', gitDir.path);
    createFile(gitDir.path, 'remote.md', 'remote');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m remote-change', gitDir.path);

    await runGitCommand('checkout master', gitDir.path);
    File(p.join(gitDir.path, 'deleted.md')).deleteSync();
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m local-delete', gitDir.path);

    await _mergeRemote(gitDir);

    expect(File(p.join(gitDir.path, 'deleted.md')).existsSync(), isFalse);
    expect(File(p.join(gitDir.path, 'remote.md')).readAsStringSync(), 'remote');
  });

  test('merge commit combines independent local and remote additions',
      () async {
    var gitDir = await Directory.systemTemp.createTemp('_git_');
    await _initRepo(gitDir);

    createFile(gitDir.path, 'base.md', 'base');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m initial', gitDir.path);

    await runGitCommand('checkout -b remote', gitDir.path);
    createFile(gitDir.path, 'remote.md', 'remote');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m remote-add', gitDir.path);

    await runGitCommand('checkout master', gitDir.path);
    createFile(gitDir.path, 'local.md', 'local');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m local-add', gitDir.path);

    await _mergeRemote(gitDir);

    expect(File(p.join(gitDir.path, 'local.md')).readAsStringSync(), 'local');
    expect(File(p.join(gitDir.path, 'remote.md')).readAsStringSync(), 'remote');
  });

  test('merge commit applies remote-only nested modification', () async {
    var gitDir = await Directory.systemTemp.createTemp('_git_');
    await _initRepo(gitDir);

    createFile(gitDir.path, 'dir/modified.md', 'base');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m initial', gitDir.path);

    await runGitCommand('checkout -b remote', gitDir.path);
    createFile(gitDir.path, 'dir/modified.md', 'remote');
    await runGitCommand('commit -am remote-change', gitDir.path);

    await runGitCommand('checkout master', gitDir.path);
    createFile(gitDir.path, 'local.md', 'local');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m local-change', gitDir.path);

    await _mergeRemote(gitDir);

    expect(File(p.join(gitDir.path, 'dir/modified.md')).readAsStringSync(),
        'remote');
    expect(File(p.join(gitDir.path, 'local.md')).readAsStringSync(), 'local');
  });

  test('merge commit applies remote move', () async {
    var gitDir = await Directory.systemTemp.createTemp('_git_');
    await _initRepo(gitDir);

    createFile(gitDir.path, 'old.md', 'contents');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m initial', gitDir.path);

    await runGitCommand('checkout -b remote', gitDir.path);
    File(p.join(gitDir.path, 'old.md')).renameSync(
      p.join(gitDir.path, 'new.md'),
    );
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m remote-move', gitDir.path);

    await runGitCommand('checkout master', gitDir.path);
    createFile(gitDir.path, 'local.md', 'local');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m local-change', gitDir.path);

    await _mergeRemote(gitDir);

    expect(File(p.join(gitDir.path, 'old.md')).existsSync(), isFalse);
    expect(File(p.join(gitDir.path, 'new.md')).readAsStringSync(), 'contents');
    expect(File(p.join(gitDir.path, 'local.md')).readAsStringSync(), 'local');
  });

  test('merge commit keeps local side when both sides modify same file',
      () async {
    var gitDir = await Directory.systemTemp.createTemp('_git_');
    await _initRepo(gitDir);

    createFile(gitDir.path, 'conflict.md', 'base');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m initial', gitDir.path);

    await runGitCommand('checkout -b remote', gitDir.path);
    createFile(gitDir.path, 'conflict.md', 'remote');
    await runGitCommand('commit -am remote-change', gitDir.path);

    await runGitCommand('checkout master', gitDir.path);
    createFile(gitDir.path, 'conflict.md', 'local');
    await runGitCommand('commit -am local-change', gitDir.path);

    await _mergeRemote(gitDir);

    expect(
        File(p.join(gitDir.path, 'conflict.md')).readAsStringSync(), 'local');
  });

  test('merge commit keeps local modification when remote deletes same file',
      () async {
    var gitDir = await Directory.systemTemp.createTemp('_git_');
    await _initRepo(gitDir);

    createFile(gitDir.path, 'conflict.md', 'base');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m initial', gitDir.path);

    await runGitCommand('checkout -b remote', gitDir.path);
    File(p.join(gitDir.path, 'conflict.md')).deleteSync();
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m remote-delete', gitDir.path);

    await runGitCommand('checkout master', gitDir.path);
    createFile(gitDir.path, 'conflict.md', 'local');
    await runGitCommand('commit -am local-change', gitDir.path);

    await _mergeRemote(gitDir);

    expect(
        File(p.join(gitDir.path, 'conflict.md')).readAsStringSync(), 'local');
  });

  test('merge commit applies remote modification when local deletes same file',
      () async {
    var gitDir = await Directory.systemTemp.createTemp('_git_');
    await _initRepo(gitDir);

    createFile(gitDir.path, 'conflict.md', 'base');
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m initial', gitDir.path);

    await runGitCommand('checkout -b remote', gitDir.path);
    createFile(gitDir.path, 'conflict.md', 'remote');
    await runGitCommand('commit -am remote-change', gitDir.path);

    await runGitCommand('checkout master', gitDir.path);
    File(p.join(gitDir.path, 'conflict.md')).deleteSync();
    await runGitCommand('add .', gitDir.path);
    await runGitCommand('commit -m local-delete', gitDir.path);

    await _mergeRemote(gitDir);

    expect(
        File(p.join(gitDir.path, 'conflict.md')).readAsStringSync(), 'remote');
  });
}

Future<void> _initRepo(Directory gitDir) async {
  await runGitCommand('init -b master', gitDir.path);
  await runGitCommand('config user.name "Test User"', gitDir.path);
  await runGitCommand('config user.email test@example.com', gitDir.path);
}

Future<void> _mergeRemote(Directory gitDir) async {
  var repo = GitRepository.load(gitDir.path);
  addTearDown(repo.close);

  var theirCommit = repo.branchCommit('remote')!;
  repo.merge(
    theirCommit: theirCommit,
    message: 'Merge remote',
    author: GitAuthor(
      name: 'Test User',
      email: 'test@example.com',
    ),
  );
}
