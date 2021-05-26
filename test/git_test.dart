import 'dart:io';

import 'package:test/test.dart';

import 'package:dart_git/git.dart';

void main() {
  test('Test can Push', () async {
    var tmpDir = (await Directory.systemTemp.createTemp('_git_')).path;

    await GitRepository.init(tmpDir);
    var repo = await GitRepository.load(tmpDir).get();
    expect(await repo.canPush(), false);
  });
}
