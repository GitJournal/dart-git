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
    'merge merge-conflict', // ours, theirs
  ];

  for (var command in commands) {
    test(command, () async => testGitCommand(s, command));
  }
}
