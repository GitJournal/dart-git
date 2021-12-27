import 'dart:io';

import 'package:test/test.dart';

import 'package:dart_git/git.dart';

void main() {
  test('Test can Push', () async {
    var tmpDir = (await Directory.systemTemp.createTemp('_git_')).path;

    GitRepository.init(tmpDir).throwOnError();
    var repo = GitRepository.load(tmpDir).getOrThrow();
    expect(repo.canPush().getOrThrow(), false);
  });
}
