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
import 'package:dart_git/utils/result.dart';
import 'commands/commands.dart';

Future<void> main(List<String> args) async {
  var ret = await mainWithExitCode(args);
  if (ret != 0) {
    exit(ret);
  }
}

Future<int> mainWithExitCode(List<String> args) async {
  var runner = CommandRunner('git', 'Distributed version control.')
    ..addCommand(InitCommand())
    ..addCommand(AddCommand())
    ..addCommand(BranchCommand())
    ..addCommand(CatFileCommand())
    ..addCommand(CheckoutCommand())
    ..addCommand(DumpIndexCommand())
    ..addCommand(HashObjectCommand())
    ..addCommand(LogCommand())
    ..addCommand(RemoteCommand())
    ..addCommand(StatusCommand())
    ..addCommand(RmCommand())
    ..addCommand(ResetCommand())
    ..addCommand(WriteTreeCommand())
    ..addCommand(MergeBaseCommand())
    ..addCommand(MergeCommand())
    ..addCommand(DiffTreeCommand())
    ..addCommand(DiffCommand())
    ..addCommand(ShowCommand())
    ..addCommand(MTimeBuilderCommand())
    ..addCommand(LsTreeCommand());

  try {
    var _ = await runner.run(args);
  } on GitException catch (e) {
    print(e);
    return 1;
  } catch (e, st) {
    var t = Result.unwindEx(e, st);
    print(t.item1);
    print(t.item2);
    return 1;
  }

  return 0;
}
