import 'package:test/test.dart';
import 'common.dart';

void main() {
  late GitCommandSetupResult s;

  setUpAll(() async {
    s = await gitCommandTestFixtureSetupAll('merge');
  });

  setUp(() async => gitCommandTestSetup(s));

  var commands = [
    'git reset --hard HEAD^',
  ];

  for (var command in commands) {
    test(command, () async => testGitCommand(s, command, ignoreOutput: true));
  }
}
