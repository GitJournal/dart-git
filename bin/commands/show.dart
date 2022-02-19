// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:diff_match_patch/src/diff.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/diff_commit.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'log.dart';

class ShowCommand extends Command {
  @override
  final name = 'show';

  @override
  final description = 'Show various types of objects';

  @override
  void run() {
    var gitRootDir = GitRepository.findRootDir(Directory.current.path)!;
    var repo = GitRepository.load(gitRootDir).getOrThrow();

    var hash = GitHash(argResults!.arguments[0]);
    var result = repo.objStorage.read(hash);
    var object = result.getOrThrow();

    if (object is GitCommit) {
      var commit = object;
      var parentHash = commit.parents[0];
      var parent = (repo.objStorage.readCommit(parentHash)).getOrThrow();

      var changes = diffCommits(
        fromCommit: commit,
        toCommit: parent,
        objStore: repo.objStorage,
      ).getOrThrow();

      printCommit(commit, hash);

      for (var change in changes.modify) {
        var newHash = change.from!.hash;
        var oldHash = change.to!.hash;

        var newBlob = (repo.objStorage.readBlob(newHash)).getOrThrow();
        var oldBlob = (repo.objStorage.readBlob(oldHash)).getOrThrow();

        var newBlobConent = utf8.decode(newBlob.blobData);
        var oldBlobConent = utf8.decode(oldBlob.blobData);

        var filePath = change.path;
        print('diff --git a/$filePath b/lib/$filePath');
        print('index .....');
        print('--- a/$filePath');
        print('+++ b/$filePath');

        var results = diff(oldBlobConent, newBlobConent);
        for (var i = 0; i < results.length; i++) {
          var diff = results[i];
          var str = '';
          if (diff.operation == -1) {
            str = '-';
          } else if (diff.operation == 1) {
            str = '+';
          } else {
            continue; // no change
          }

          // Prev context
          const prevLinesOfContext = 3;
          if (i > 0 && results[i - 1].operation == 0) {
            var lines = LineSplitter.split(results[i - 1].text).toList();
            if (lines.length > prevLinesOfContext) {
              lines = lines.sublist(lines.length - prevLinesOfContext);
            }

            // FIXME: Figure out how to show the correct line numbers!
            print('@@ -30,11 +30,10 @@ ...');
            for (var line in lines) {
              print(' $line');
            }
          }

          // Current op
          for (var line in LineSplitter.split(diff.text)) {
            print(str + line);
          }

          // After context
          const afterLinesOfContext = 3;
          if (i < results.length - 1 && results[i + 1].operation == 0) {
            var lines = LineSplitter.split(results[i + 1].text).toList();
            for (var i = 0; i < lines.length && i < afterLinesOfContext; i++) {
              var line = lines[i];
              print(' $line');
            }
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

  var dmp = DiffMatchPatch();
  var diffObjects = dmp.diff(chars1, chars2);
  charsToLines(diffObjects, lineArray);

  return diffObjects;
}
