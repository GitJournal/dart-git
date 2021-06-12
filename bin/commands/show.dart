import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/diff_commit.dart';
import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'log.dart';

import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:diff_match_patch/src/diff.dart';

class ShowCommand extends Command {
  @override
  final name = 'show';

  @override
  final description = 'Show various types of objects';

  @override
  Future run() async {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = await GitRepository.load(gitRootDir).getOrThrow();

    var hash = GitHash(argResults!.arguments[0]);
    var result = await repo.objStorage.read(hash);
    var object = result.getOrThrow();

    if (object is GitCommit) {
      var commit = object;
      var parentHash = commit.parents[0];
      var parent = (await repo.objStorage.readCommit(parentHash)).getOrThrow();

      var changes = await diffCommits(
        fromCommit: commit,
        toCommit: parent,
        objStore: repo.objStorage,
      ).getOrThrow();

      printCommit(commit, hash);

      for (var change in changes.modified) {
        var newHash = change.from!.hash;
        var oldHash = change.to!.hash;

        var newBlob = (await repo.objStorage.readBlob(newHash)).getOrThrow();
        var oldBlob = (await repo.objStorage.readBlob(oldHash)).getOrThrow();

        var newBlobConent = utf8.decode(newBlob.blobData);
        var oldBlobConent = utf8.decode(oldBlob.blobData);

        var filePath = change.path;
        print('diff --git a/$filePath b/lib/$filePath');
        print('index .....');
        print('--- a/$filePath');
        print('+++ b/$filePath');

        var results = diff(oldBlobConent, newBlobConent);
        for (var diff in results) {
          var str = '';
          if (diff.operation == 0) {
            str += '   ';
          } else if (diff.operation == -1) {
            str += ' - ';
          } else if (diff.operation == 1) {
            str += ' + ';
          }
          assert(str.isNotEmpty);

          for (var line in LineSplitter.split(diff.text)) {
            print(str + line);
          }
        }
      }
    } else {
      print('no other git type is currentyl supported');
    }
  }
}

List<Diff> diff(String a, String b) {
  var res = linesToChars(a, b);
  var chars1 = res['chars1'] as String;
  var chars2 = res['chars2'] as String;
  var lineArray = res['lineArray'] as List<String>;
  // print(chars1.codeUnits);
  // print(chars2.codeUnits);
  // print(lineArray);

  var dmp = DiffMatchPatch();
  var diffObjects = dmp.diff(chars1, chars2);
  charsToLines(diffObjects, lineArray);

  return diffObjects;
}
