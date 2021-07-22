import 'package:test/test.dart';

import 'common.dart';

void main() {
  late GitCommandSetupResult s;

  setUpAll(() async {
    s = await gitCommandTestFixtureSetupAll('merge');
  });

  setUp(() async => gitCommandTestSetup(s));

  var commands = [
    'merge fast-forward',
    'merge up-to-date',
    'merge merge-conflict -X ours',
    // 'merge merge-conflict -X theirs', // ours, theirs
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

// FIXME: We aren't taking directories into account!
// FIXME: A directory is now a file from both branches
