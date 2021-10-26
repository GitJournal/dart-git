import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/utils/date_time_tz_offset.dart';
import 'package:dart_git/utils/kvlm.dart';

class GitAuthor {
  String name;
  String email;

  /// timezone offset in format '0430'
  late int timezoneOffset;
  late DateTime date;

  Duration get timezoneOffsetDuration {
    return Duration(
      hours: timezoneOffset ~/ 100,
      minutes: timezoneOffset % 100,
    );
  }

  DateTimeWithTzOffset get dateWithOffset {
    return DateTimeWithTzOffset.fromDt(timezoneOffsetDuration, date);
  }

  GitAuthor({
    required this.name,
    required this.email,
    DateTime? date,
    int? timezoneOffset,
  }) {
    this.date = date ?? DateTime.now();

    this.timezoneOffset = timezoneOffset ??
        this.date.timeZoneOffset.inHours * 100 +
            (this.date.timeZoneOffset.inMinutes % 60);
  }

  static GitAuthor? parse(String input) {
    // Regex " AuthorName <Email>  timestamp timeOffset"
    var pattern = RegExp(r'(.*) <(.*)> (\d+) ([+\-]\d\d\d\d)');
    var match = pattern.allMatches(input).toList();
    if (match.isEmpty) {
      return null;
    }

    var timestamp = (int.parse(match[0].group(3)!)) * 1000;
    return GitAuthor(
      name: match[0].group(1)!,
      email: match[0].group(2)!,
      date: DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true),
      timezoneOffset: int.parse(match[0].group(4)!),
    );
  }

  String serialize() {
    var timestamp = date.toUtc().millisecondsSinceEpoch / 1000;
    var offset = timezoneOffset >= 0
        ? '+${timezoneOffset.toString().padLeft(4, "0")}'
        : '-${timezoneOffset.abs().toString().padLeft(4, "0")}';

    return '$name <$email> ${timestamp.toInt()} $offset';
  }

  @override
  String toString() {
    return 'GitAuthor(name: $name, email: $email, date: $date, offset: $timezoneOffset)';
  }
}

class GitCommit extends GitObject {
  static const fmt = ObjectTypes.COMMIT_STR;
  static final _fmt = ascii.encode(fmt);

  GitAuthor author;
  GitAuthor committer;
  String message;
  GitHash treeHash;
  List<GitHash> parents = [];
  String gpgSig = '';

  GitHash? _hash;

  GitCommit.create({
    required this.author,
    required this.committer,
    required this.message,
    required this.treeHash,
    required this.parents,
    this.gpgSig = '',
  }) : _hash = null;

  static GitCommit? parse(Uint8List rawData, GitHash? hash) {
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
  GitHash get hash {
    _hash ??= GitHash.compute(serialize());
    return _hash!;
  }

  @override
  String toString() => '$hash - ${_toMap().toString()}';
}
