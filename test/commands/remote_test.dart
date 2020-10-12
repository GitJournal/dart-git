import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../lib.dart';

void main() {
  test('remote', () async {
    var printLog = await runDartGitCommand('remote', Directory.current.path);
    expect(printLog, ['origin']);
  });

  test('remote -v', () async {
    var tmpDir1 = (await Directory.systemTemp.createTemp('_git_real_')).path;
    await runGitCommand(
      tmpDir1,
      'clone https://github.com/GitJournal/dart_git.git',
    );

    var printLog =
        await runDartGitCommand('remote -v', p.join(tmpDir1, 'dart_git'));
    expect(printLog, [
      'origin	https://github.com/GitJournal/dart_git.git (fetch)',
      'origin	https://github.com/GitJournal/dart_git.git (push)',
    ]);
  });
}
