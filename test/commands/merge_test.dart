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
    // 'merge merge-conflict -X ours',
    // 'merge merge-conflict -X theirs', // ours, theirs
  ];

  for (var command in commands) {
    test(command, () async => testGitCommand(s, command, ignoreOutput: true));
  }
}

// FIXME: We aren't taking directories into account!
// FIXME: A directory is now a file from both branches
