import 'package:args/command_runner.dart';
import 'commands/commands.dart';

void main(List<String> args) async {
  var runner = CommandRunner('git', 'Distributed version control.')
    ..addCommand(InitCommand())
    ..addCommand(CatFileCommand())
    ..addCommand(HashObjectCommand());

  try {
    await runner.run(args);
  } catch (e) {
    print(e);
    return;
  }
}
