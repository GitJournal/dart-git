#!/usr/bin/env dart
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

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/exceptions.dart';
import 'commands/commands.dart';

Future<void> main(List<String> args) async {
  var ret = await mainWithExitCode(args, Directory.current.path);
  if (ret != 0) {
    exit(ret);
  }
}

Future<int> mainWithExitCode(List<String> args, String currentDir) async {
  var runner = CommandRunner<int>('git', 'Distributed version control.')
    ..addCommand(InitCommand(currentDir))
    ..addCommand(AddCommand(currentDir))
    ..addCommand(BranchCommand(currentDir))
    ..addCommand(CatFileCommand(currentDir))
    ..addCommand(CheckoutCommand(currentDir))
    ..addCommand(DumpIndexCommand(currentDir))
    ..addCommand(HashObjectCommand(currentDir))
    ..addCommand(LogCommand(currentDir))
    ..addCommand(RemoteCommand(currentDir))
    ..addCommand(StatusCommand(currentDir))
    ..addCommand(RmCommand(currentDir))
    ..addCommand(ResetCommand(currentDir))
    ..addCommand(WriteTreeCommand(currentDir))
    ..addCommand(MergeBaseCommand(currentDir))
    ..addCommand(MergeCommand(currentDir))
    ..addCommand(DiffTreeCommand(currentDir))
    ..addCommand(DiffCommand(currentDir))
    ..addCommand(ShowCommand(currentDir))
    ..addCommand(MTimeBuilderCommand(currentDir))
    ..addCommand(LsTreeCommand(currentDir));

  try {
    return await runner.run(args) ?? 100;
  } on GitException catch (e, st) {
    print(e);
    print(st);
    return 1;
  } catch (e, st) {
    print(e);
    print(st);
    return 1;
  }
}
