import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/diff_commit.dart';
import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'log.dart';

// import 'package:fire_line_diff/fire_line_diff.dart';

class ShowCommand extends Command {
  @override
  final name = 'show';

  @override
  final description = 'Show various types of objects';

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = await GitRepository.load(gitRootDir).get();

    var hash = GitHash(argResults!.arguments[0]);
    var result = await repo.objStorage.read(hash);
    var object = result.get();

    if (object is GitCommit) {
      var commit = object;
      var parentHash = commit.parents[0];
      var parent = (await repo.objStorage.readCommit(parentHash)).get();

      var changes = await diffCommits(
        fromCommit: commit,
        toCommit: parent,
        objStore: repo.objStorage,
      );

      printCommit(commit, hash);

      for (var change in changes.modified) {
        var newHash = change.from!.hash;
        var oldHash = change.to!.hash;

        var newBlob = (await repo.objStorage.readBlob(newHash)).get();
        var oldBlob = (await repo.objStorage.readBlob(oldHash)).get();

        var newBlobConent = utf8.decode(newBlob.blobData);
        var oldBlobConent = utf8.decode(oldBlob.blobData);

        var newList = LineSplitter.split(newBlobConent).toList();
        var oldList = LineSplitter.split(oldBlobConent).toList();

        print(oldList);
        print(newList);

        // var result = FireLineDiff.diff(oldList, newList);
        // print(result);
      }
    } else {
      print('no other git type is currentyl supported');
    }
  }
}
