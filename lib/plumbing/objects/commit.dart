import 'dart:convert';

import 'package:meta/meta.dart';

import 'package:dart_git/ascii_helper.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';

class GitAuthor {
  String name;
  String email;
  int timestamp;
  int timezoneOffset;
  DateTime date;

  GitAuthor({
    @required this.name,
    @required this.email,
    this.date,
    this.timezoneOffset,
  }) {
    if (date == null) {
      date = DateTime.now();
      timestamp = date.millisecondsSinceEpoch;
    }

    timezoneOffset ??= date.timeZoneOffset.inHours * 100 +
        (date.timeZoneOffset.inMinutes % 60);
  }

  GitAuthor._internal();

  static GitAuthor parse(String input) {
    // Regex " AuthorName <Email>  timestamp timeOffset"
    var pattern = RegExp(r'(.*) <(.*)> (\d+) ([+\-]\d\d\d\d)');
    var match = pattern.allMatches(input).toList();

    var author = GitAuthor._internal();
    author.name = match[0].group(1);
    author.email = match[0].group(2);
    author.timestamp = (int.parse(match[0].group(3))) * 1000;
    author.date =
        DateTime.fromMillisecondsSinceEpoch(author.timestamp, isUtc: true);
    author.timezoneOffset = int.parse(match[0].group(4));
    return author;
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
    if (timestamp != 0) {
      return 'GitAuthor(name: $name, email: $email, date: $date)';
    }
    return 'GitAuthor(name: $name, email: $email)';
  }
}

class GitCommit extends GitObject {
  static const String fmt = ObjectTypes.COMMIT_STR;
  static final List<int> _fmt = ascii.encode(fmt);

  GitAuthor author;
  GitAuthor committer;
  String message;
  GitHash treeHash;
  List<GitHash> parents = [];
  String gpgSig;

  GitHash _hash;

  GitCommit.create({
    @required this.author,
    @required this.committer,
    @required this.message,
    @required this.treeHash,
    @required this.parents,
    this.gpgSig = '',
  }) : _hash = null;

  GitCommit(List<int> rawData, this._hash) {
    var map = kvlmParse(rawData);
    message = map['_'];
    author = GitAuthor.parse(map['author']);
    committer = GitAuthor.parse(map['committer']);

    if (map.containsKey('parent')) {
      var parent = map['parent'];
      if (parent is List) {
        parent.forEach((p) => parents.add(GitHash(p as String)));
      } else if (parent is String) {
        parents.add(GitHash(parent));
      } else {
        throw Exception('Unknow parent type');
      }
    }
    treeHash = GitHash(map['tree']);
    gpgSig = map['gpgsig'] ?? '';
  }

  @override
  List<int> serializeData() {
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
  List<int> format() => _fmt;

  @override
  String formatStr() => fmt;

  @override
  GitHash get hash {
    _hash ??= GitHash.compute(serialize());
    return _hash;
  }

  @override
  String toString() => _toMap().toString();
}

Map<String, dynamic> kvlmParse(List<int> raw) {
  var dict = <String, dynamic>{};

  var start = 0;
  while (true) {
    var spaceIndex = raw.indexOf(asciiHelper.space, start);
    var newLineIndex = raw.indexOf(asciiHelper.newLine, start);

    if (newLineIndex < spaceIndex || spaceIndex == -1) {
      assert(newLineIndex == start);

      dict['_'] = utf8.decode(raw.sublist(start + 1));
      break;
    }

    var key = raw.sublist(start, spaceIndex);
    var end = spaceIndex;
    while (true) {
      end = raw.indexOf(asciiHelper.newLine, end + 1);
      if (raw[end + 1] != asciiHelper.space) {
        break;
      }
    }

    var value = raw.sublist(spaceIndex + 1, end);
    var valueStr = utf8.decode(value).replaceAll('\n ', '\n');

    var keyStr = utf8.decode(key);
    if (dict.containsKey(keyStr)) {
      var dictVal = dict[keyStr];
      if (dictVal is List) {
        dict[keyStr] = [...dictVal, valueStr];
      } else {
        dict[keyStr] = [dictVal, valueStr];
      }
    } else {
      dict[keyStr] = valueStr;
    }

    start = end + 1;
  }

  return dict;
}

List<int> kvlmSerialize(Map<String, dynamic> kvlm) {
  var ret = <int>[];

  kvlm.forEach((key, val) {
    if (key == '_') {
      return;
    }

    if (val is! List) {
      val = [val];
    }

    val.forEach((v) {
      ret.addAll([
        ...utf8.encode(key),
        asciiHelper.space,
        ...utf8.encode(v.replaceAll('\n', '\n ')),
        asciiHelper.newLine,
      ]);
    });
  });

  ret.addAll([asciiHelper.newLine, ...utf8.encode(kvlm['_'])]);
  return ret;
}
