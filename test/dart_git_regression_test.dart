/*
 * SPDX-FileCopyrightText: 2026 Vishesh Handa <me@vhanda.in>
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import 'dart:convert';
import 'dart:io';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/utils/file_mode.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String repoPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dart_git_regression_');
    repoPath = tempDir.path;
    GitRepository.init(repoPath);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('add dot stages modified tracked file contents', () {
    _writeFile(repoPath, 'note.md', 'before\n');

    var repo = GitRepository.load(repoPath);
    repo.add('.');
    var firstCommit = repo.commit(
      message: 'Initial commit',
      author: _author,
    );

    _writeFile(repoPath, 'note.md', 'after\n');
    repo.add('.');
    var secondCommit = repo.commit(
      message: 'Update note',
      author: _author,
    );
    repo.close();

    expect(secondCommit.parents, [firstCommit.hash]);

    var loadedRepo = GitRepository.load(repoPath);
    expect(_blobContents(loadedRepo, 'note.md'), 'after\n');
    loadedRepo.close();
  });

  test('add dot stages filesystem renames as delete plus add', () {
    _writeFile(repoPath, '1.md', 'one\n');
    _writeFile(repoPath, '2.md', 'two\n');

    var repo = GitRepository.load(repoPath);
    repo.add('.');
    var firstCommit = repo.commit(
      message: 'Initial commit',
      author: _author,
    );

    Directory(p.join(repoPath, 'folder')).createSync();
    File(p.join(repoPath, '1.md')).renameSync(p.join(repoPath, 'folder/1.md'));

    repo.add('.');
    var secondCommit = repo.commit(
      message: 'Rename note',
      author: _author,
    );
    repo.close();

    expect(secondCommit.parents, [firstCommit.hash]);

    var loadedRepo = GitRepository.load(repoPath);
    expect(_treePaths(loadedRepo), ['2.md', 'folder/1.md']);
    expect(_blobContents(loadedRepo, 'folder/1.md'), 'one\n');
    loadedRepo.close();
  });

  test('addFileToIndex reuses existing entry with portable metadata', () {
    _writeFile(repoPath, 'note.md', 'stable\n');

    var repo = GitRepository.load(repoPath);
    var index = repo.indexStorage.readIndex();

    var firstEntry = repo.addFileToIndex(index, p.join(repoPath, 'note.md'));
    var secondEntry = repo.addFileToIndex(index, p.join(repoPath, 'note.md'));

    expect(identical(firstEntry, secondEntry), true);
    expect(index.entries, hasLength(1));

    repo.close();
  });
}

final _author = GitAuthor(
  name: 'Test Author',
  email: 'test@example.com',
  date: DateTime.utc(2026, 1, 1),
);

void _writeFile(String repoPath, String pathSpec, String contents) {
  var file = File(p.join(repoPath, pathSpec));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

List<String> _treePaths(GitRepository repo) {
  var commit = repo.headCommit();
  var tree = repo.objStorage.readTree(commit.treeHash);
  var paths = _treeEntryPaths(repo, tree).toList()..sort();
  return paths;
}

Iterable<String> _treeEntryPaths(
  GitRepository repo,
  GitTree tree, [
  String prefix = '',
]) sync* {
  for (var entry in tree.entries) {
    var path = prefix.isEmpty ? entry.name : p.join(prefix, entry.name);
    if (entry.mode == GitFileMode.Dir) {
      var subTree = repo.objStorage.readTree(entry.hash);
      yield* _treeEntryPaths(repo, subTree, path);
    } else {
      yield path;
    }
  }
}

String _blobContents(GitRepository repo, String pathSpec) {
  var commit = repo.headCommit();
  var tree = repo.objStorage.readTree(commit.treeHash);
  var entry = _findTreeEntry(repo, tree, pathSpec.split('/'));
  var blob = repo.objStorage.read(entry.hash) as GitBlob;
  return utf8.decode(blob.blobData);
}

GitTreeEntry _findTreeEntry(
  GitRepository repo,
  GitTree tree,
  List<String> pathParts,
) {
  var entry = tree.entries.firstWhere((entry) => entry.name == pathParts.first);
  if (pathParts.length == 1) {
    return entry;
  }

  var subTree = repo.objStorage.readTree(entry.hash);
  return _findTreeEntry(repo, subTree, pathParts.sublist(1));
}
