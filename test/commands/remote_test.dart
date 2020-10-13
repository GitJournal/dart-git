import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../lib.dart';

void main() {
  String gitDir;

  setUp(() async {
    var tmpDir1 = (await Directory.systemTemp.createTemp('_git_')).path;
    await runGitCommand(
        'clone https://github.com/GitJournal/dart_git.git', tmpDir1);
    gitDir = p.join(tmpDir1, 'dart_git');
  });

  Future<void> _testCommand(String command) async {
    var output = await runDartGitCommand(command, gitDir);
    var expectedOutput = await runGitCommand(command, gitDir);

    expect(output.join('\n').trim(), expectedOutput);
  }

  test('remote', () => _testCommand('remote'));
  test('remote -v', () => _testCommand('remote -v'));
}
