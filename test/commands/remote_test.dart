import 'package:test/test.dart';

import '../lib.dart';

void main() {
  test('remote', () async {
    var printLog = await runDartGitCommand('remote');
    expect(printLog, ['origin']);
  });

  test('remote -v', () async {
    var printLog = await runDartGitCommand('remote -v');
    expect(printLog, [
      'origin	git@github.com:GitJournal/dart_git.git (fetch)',
      'origin	git@github.com:GitJournal/dart_git.git (push)',
    ]);
  });
}
