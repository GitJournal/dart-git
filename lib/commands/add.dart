import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/index.dart';

class AddCommand extends Command {
  @override
  final name = 'add';

  @override
  final description = 'Add file contents to the index';

  AddCommand() {
    //argParser.addCommand(name);
  }

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path);
    var repo = await GitRepository.load(gitRootDir);

    var filePath = argResults.arguments[0];
    var file = File(filePath);
    if (!file.existsSync()) {
      print("fatal: pathspec '$filePath' did not match any files");
      return false;
    }

    // Save that file as a blob
    var data = await file.readAsBytes();
    var blob = GitBlob(data, null);
    var hash = await repo.writeObject(blob);

    // FIXME: Get proper pathSpec
    var pathSpec = filePath;

    // Add it to the index
    var index = await repo.index();
    GitIndexEntry entry;
    for (var e in index.entries) {
      if (e.path == pathSpec) {
        entry = e;
        break;
      }
    }

    var stat = await FileStat.stat(filePath);

    // Existing file
    if (entry != null) {
      entry.hash = hash;
      entry.fileSize = data.length;

      entry.cTime = stat.changed;
      entry.mTime = stat.modified;

      await repo.writeIndex(index);
      return;
    }

    // New file
    entry = GitIndexEntry.fromFS(pathSpec, stat, hash);
    index.entries.add(entry);
    await repo.writeIndex(index);
  }
}
