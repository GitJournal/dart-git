import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/utils/date_time.dart';
import 'package:dart_git/utils/kvlm.dart';
import 'package:meta/meta.dart';

@immutable
class GitAuthor {
  final String name;
  final String email;

  late final DateTime date;

  GitAuthor({required this.name, required this.email, DateTime? date}) {
    this.date = date ?? DateTime.now();
  }

  static GitAuthor? parse(String input) {
    // Regex " AuthorName <Email>  timestamp timeOffset"
    var pattern = RegExp(r'(.*) <(.*)> (\d+) ([+\-]\d\d\d\d)');
    var match = pattern.allMatches(input).toList();
    if (match.isEmpty) {
      return null;
    }

    var timestamp = int.parse(match[0].group(3)!);
    var offset = int.parse(match[0].group(4)!);
    var offsetDuration = Duration(hours: offset ~/ 100, minutes: offset % 100);

    return GitAuthor(
      name: match[0].group(1)!,
      email: match[0].group(2)!,
      date: GDateTime.fromTimeStamp(offsetDuration, timestamp),
    );
  }

  String serialize() {
    var timestamp = date.toUtc().millisecondsSinceEpoch / 1000;

    /// timezone offset in format '0430'
    var gitTimeZoneOffset = date.timeZoneOffset.inHours * 100 +
        (date.timeZoneOffset.inMinutes % 60);

    var offset = gitTimeZoneOffset >= 0
        ? '+${gitTimeZoneOffset.toString().padLeft(4, "0")}'
        : '-${gitTimeZoneOffset.abs().toString().padLeft(4, "0")}';

    return '$name <$email> ${timestamp.toInt()} $offset';
  }

  @override
  String toString() {
    return 'GitAuthor(name: $name, email: $email, date: $date)';
  }
}

@immutable
class GitCommit extends GitObject {
  static const fmt = ObjectTypes.COMMIT_STR;
  static final _fmt = ascii.encode(fmt);

  final GitAuthor author;
  final GitAuthor committer;
  final String message;
  final GitHash treeHash;
  final List<GitHash> parents;
  final String gpgSig;

  @override
  late final GitHash hash;

  GitCommit.create({
    required this.author,
    required this.committer,
    required this.message,
    required this.treeHash,
    required this.parents,
    this.gpgSig = '',
    GitHash? hash,
  }) {
    this.hash = hash ?? GitHash.computeForObject(this);
  }

  static GitCommit? parse(Uint8List rawData, GitHash hash) {
    var map = kvlmParse(rawData);
    var requiredKeys = ['author', 'committer', 'tree', '_'];
    for (var key in requiredKeys) {
      if (!map.containsKey(key)) {
        // FIXME: At least log the error?
        return null;
      }
    }

    var message = map['_'] ?? '';
    var author = GitAuthor.parse(map['author'])!;
    var committer = GitAuthor.parse(map['committer'])!;
    var parents = <GitHash>[];

    if (map.containsKey('parent')) {
      var parent = map['parent'];
      if (parent is List) {
        for (var p in parent) {
          parents.add(GitHash(p as String));
        }
      } else if (parent is String) {
        parents.add(GitHash(parent));
      } else {
        // FIXME: At least log the error?
        return null;
      }
    }
    var treeHash = GitHash(map['tree']);
    var gpgSig = map['gpgsig'] ?? '';

    return GitCommit.create(
      hash: hash,
      author: author,
      committer: committer,
      message: message,
      treeHash: treeHash,
      parents: parents,
      gpgSig: gpgSig,
    );
  }

  @override
  Uint8List serializeData() {
    return kvlmSerialize(_toMap());
  }

  Map<String, dynamic> _toMap() {
    var map = <String, dynamic>{
      'tree': treeHash.toString(),
    };

    if (parents.length == 1) {
      map['parent'] = parents[0].toString();
    } else {
      map['parent'] = parents.map((e) => e.toString()).toList();
    }
    map['author'] = author.serialize();
    map['committer'] = committer.serialize();
    if (gpgSig.isNotEmpty) {
      map['gpgsig'] = gpgSig;
    }

    map['_'] = message;
    return map;
  }

  @override
  Uint8List format() => _fmt;

  @override
  String formatStr() => fmt;

  @override
  String toString() => '$hash - ${_toMap().toString()}';
}
