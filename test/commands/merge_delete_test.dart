import 'package:test/test.dart';

import 'common.dart';

void main() {
  late GitCommandSetupResult s;

  setUpAll(() async {
    s = await gitCommandTestFixtureSetupAll('merge-delete');
  });

  setUp(() async => gitCommandTestSetup(s));

  var commands = [
    'merge del2',
  ];

  for (var command in commands) {
    test(
        command,
        () async => testGitCommand(s, command, ignoreOutput: true, env: {
              'GIT_AUTHOR_DATE': '2020-02-15T09:08:07.000Z',
              'GIT_AUTHOR_NAME': 'Vishesh Handa',
              'GIT_AUTHOR_EMAIL': 'me@vhanda.in',
              'GIT_COMMITTER_DATE': '2020-02-15T09:08:07.000Z',
              'GIT_COMMITTER_NAME': 'Vishesh Handa',
              'GIT_COMMITTER_EMAIL': 'me@vhanda.in',
            }));
  }
}
