/*
  Dart Git
  Copyright (C) 2020  Vishesh Handa

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU Affero General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU Affero General Public License for more details.

  You should have received a copy of the GNU Affero General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import 'package:args/command_runner.dart';
import 'commands/commands.dart';

void main(List<String> args) async {
  var runner = CommandRunner('git', 'Distributed version control.')
    ..addCommand(InitCommand())
    ..addCommand(BranchCommand())
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
