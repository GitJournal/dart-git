import 'commands/init.dart';
import 'commands/cat_file.dart';
import 'commands/hash_object.dart';

import 'package:args/command_runner.dart';

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
