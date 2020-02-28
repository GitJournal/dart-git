import 'package:args/command_runner.dart';
import 'commands/commands.dart';

void main(List<String> args) async {
  var runner = CommandRunner('git', 'Distributed version control.')
    ..addCommand(InitCommand())
    ..addCommand(CatFileCommand())
    ..addCommand(HashObjectCommand())
    ..addCommand(LogCommand())
    ..addCommand(LsTreeCommand());

  try {
    await runner.run(args);
  } catch (e, stacktrace) {
    print(e);
    print(stacktrace);
    return;
  }
}
