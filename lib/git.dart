import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';

import 'package:path/path.dart' as p;
import 'package:ini/ini.dart';
import 'package:crypto/crypto.dart';

void main(List<String> args) async {
  var parser = ArgParser();
  var catFileCommand = ArgParser();

  parser.addCommand('cat-file', catFileCommand);

  var results = parser.parse(args);
  var cmd = results.command;
  if (cmd == null) {
    print(parser.usage);
    exit(0);
  }

  if (cmd.name == 'cat-file') {
    var repo = GitRepository(Directory.current.path);

    var objectSha1 = cmd.arguments[1];
    var obj = await repo.readObjectFromSha(objectSha1);
    if (obj is GitBlob) {
      var s = utf8.decode(obj.blobData);
      print(s);
    }
  }
}

class GitRepository {
  String workTree;
  String gitDir;
  Map<String, dynamic> config;

  GitRepository(String path) {
    workTree = path;
    gitDir = p.join(workTree, '.git');

    /*if (!FileSystemEntity.isDirectorySync(gitDir)) {
      throw InvalidRepoException(path);
    }*/
  }

  static Future<void> init(String path) async {
    // TODO: Check if path has stuff and accordingly return

    var gitDir = p.join(path, '.git');

    await Directory(p.join(gitDir, 'branches')).create(recursive: true);
    await Directory(p.join(gitDir, 'objects')).create(recursive: true);
    await Directory(p.join(gitDir, 'refs', 'tags')).create(recursive: true);
    await Directory(p.join(gitDir, 'refs', 'heads')).create(recursive: true);

    await File(p.join(gitDir, 'description')).writeAsString(
        "Unnamed repository; edit this file 'description' to name the repository.\n");
    await File(p.join(gitDir, 'HEAD'))
        .writeAsString('ref: refs/heads/master\n');

    var config = Config();
    config.addSection('core');
    config.set('core', 'repositoryformatversion', '0');
    config.set('core', 'filemode', 'false');
    config.set('core', 'bare', 'false');

    await File(p.join(gitDir, 'config')).writeAsString(config.toString());
  }

  Future<GitObject> readObjectFromSha(String sha) async {
    var path = p.join(gitDir, 'objects', sha.substring(0, 2), sha.substring(2));
    return readObjectFromPath(path);
  }

  Future<GitObject> readObjectFromPath(String filePath) async {
    var contents = await File(filePath).readAsBytes();
    var raw = zlib.decode(contents);

    // Read Object Type
    var x = raw.indexOf(' '.codeUnitAt(0));
    var fmt = raw.sublist(0, x);

    // Read and validate object size
    var y = raw.indexOf(0x0, x);
    var size = int.parse(ascii.decode(raw.sublist(x, y)));
    if (size != (raw.length - y - 1)) {
      throw Exception('Malformed object $filePath: bad length');
    }

    var fmtStr = ascii.decode(fmt);
    if (fmtStr == GitBlob.fmt) {
      return GitBlob(raw.sublist(y + 1));
    } else if (fmtStr == GitCommit.fmt) {
      return GitCommit(raw.sublist(y + 1));
    } else {
      throw Exception('Unknown type ${ascii.decode(fmt)} for object $filePath');
    }

    // Handle commits, tags and trees
  }

  Future<String> writeObject(GitObject obj, {bool write = true}) async {
    var result = serializeObject(obj);
    var sha = sha1.convert(result).toString();

    if (write) {
      var path =
          p.join(gitDir, 'objects', sha.substring(0, 2), sha.substring(2));
      await File(path).writeAsBytes(zlib.encode(result));
    }

    return sha;
  }

  List<int> serializeObject(GitObject obj) {
    var data = obj.serialize();
    return [
      ...obj.format(),
      ...ascii.encode(' '),
      ...ascii.encode(data.length.toString()),
      0x0,
      ...data,
    ];
  }
}

class GitException implements Exception {}

class InvalidRepoException implements GitException {
  String path;
  InvalidRepoException(this.path);

  @override
  String toString() => 'Not a Git Repository: ' + path;
}

abstract class GitObject {
  List<int> serialize();
  List<int> format();
}

// FIXME: Every object should know its sha1
class GitBlob extends GitObject {
  static const String fmt = 'blob';
  static final List<int> _fmt = ascii.encode(fmt);

  List<int> blobData;

  GitBlob(this.blobData);

  @override
  List<int> serialize() => blobData;

  @override
  List<int> format() => _fmt;
}

class Author {
  String name;
  String email;
  int timestamp;
  DateTime date;

  static Author parse(String input) {
    // Regex " AuthorName <Email>  timestamp timeOffset"
    var pattern = RegExp(r'(.*) <(.*)> (\d+) (\+|\-)\d\d\d\d');
    var match = pattern.allMatches(input).toList();

    var author = Author();
    author.name = match[0].group(1);
    author.email = match[0].group(2);
    author.timestamp = (int.parse(match[0].group(3))) * 1000;
    author.date =
        DateTime.fromMillisecondsSinceEpoch(author.timestamp, isUtc: true);
    return author;
  }
}

class GitCommit extends GitObject {
  static const String fmt = 'commit';
  static final List<int> _fmt = ascii.encode(fmt);

  Map<String, List<int>> props;
  Author author;
  Author committer;
  String message;
  String treeSha;
  List<String> parents = [];

  GitCommit(List<int> rawData) {
    var map = kvlmParse(rawData);
    message = map['_'];
    author = map['author'];
    committer = map['committer'];

    if (map.containsKey('parent')) {
      map['parent'].forEach((p) => parents.add(p as String));
    }
    treeSha = map['tree'];
  }

  @override
  List<int> serialize() => [];

  @override
  List<int> format() => _fmt;
}

Map<String, dynamic> kvlmParse(List<int> raw) {
  var dict = <String, dynamic>{};

  var start = 0;
  var spaceRaw = ' '.codeUnitAt(0);
  var newLineRaw = '\n'.codeUnitAt(0);

  while (true) {
    var spaceIndex = raw.indexOf(spaceRaw, start);
    var newLineIndex = raw.indexOf(newLineRaw, start);

    if (newLineIndex < spaceIndex) {
      assert(newLineIndex == start);

      dict['_'] = utf8.decode(raw.sublist(start + 1));
      break;
    }

    var key = raw.sublist(start, spaceIndex);
    var end = spaceIndex;
    while (true) {
      end = raw.indexOf(newLineRaw, end + 1);
      if (raw[end + 1] != spaceRaw) {
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
        ' '.codeUnitAt(0),
        ...utf8.encode(v.replaceAll('\n', '\n ')),
        '\n'.codeUnitAt(0),
      ]);
    });
  });

  ret.addAll(['\n'.codeUnitAt(0), ...utf8.encode(kvlm['_'])]);
  return ret;
}
