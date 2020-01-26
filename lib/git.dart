import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:ini/ini.dart';
import 'package:crypto/crypto.dart';

void main() {
  print('Hello World');
}

class GitRepository {
  String workTree;
  String gitDir;
  Map<String, dynamic> config;

  GitRepository(String path) {
    workTree = path;
    gitDir = p.join(workTree, '.git');

    if (!FileSystemEntity.isDirectorySync(gitDir)) {
      throw InvalidRepoException(path);
    }
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

  Future<GitObject> readObject(String sha) async {
    var path = p.join(gitDir, 'objects', sha.substring(0, 2), sha.substring(2));

    var contents = await File(path).readAsBytes();
    var raw = zlib.decode(contents);

    // Read Object Type
    var x = raw.indexOf(' '.codeUnitAt(0));
    var fmt = raw.sublist(0, x);

    // Read and validate object size
    var y = raw.indexOf(0, x);
    var size = int.parse(ascii.decode(raw.sublist(x, y)));
    if (size != (raw.length - y - 1)) {
      throw Exception('Malformed object $sha: bad length');
    }

    if (fmt == GitBlob.fmt) {
      return GitBlob(this, raw.sublist(y + 1));
    } else {
      throw Exception('Unknown type ${ascii.decode(fmt)} for object $sha');
    }

    // Handle commits, tags and trees
  }

  Future<String> writeObject(GitObject obj, {bool write = true}) async {
    var data = obj.serialize();
    var result = [...obj.format(), ...ascii.encode(' '), 0, ...data];
    var sha = sha1.convert(result).toString();

    if (write) {
      var path =
          p.join(gitDir, 'objects', sha.substring(0, 2), sha.substring(2));
      await File(path).writeAsBytes(result);
    }

    return sha;
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

class GitBlob extends GitObject {
  static List<int> fmt = ascii.encode('blob');

  GitRepository repo;
  List<int> blobData;

  GitBlob(this.repo, this.blobData);

  @override
  List<int> serialize() => blobData;

  @override
  List<int> format() => fmt;
}
