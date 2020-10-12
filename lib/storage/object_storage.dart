import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/ascii_helper.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/objects/object.dart';

class ObjectStorage {
  final String gitDir;
  final FileSystem fs;

  const ObjectStorage(this.gitDir, this.fs);

  Future<GitObject> readObjectFromHash(GitHash hash) async {
    var sha = hash.toString();
    var path = p.join(gitDir, 'objects', sha.substring(0, 2), sha.substring(2));
    return readObjectFromPath(path);
  }

  Future<GitObject> readObjectFromPath(String filePath) async {
    var contents = await fs.file(filePath).readAsBytes();
    var raw = zlib.decode(contents);

    // Read Object Type
    var x = raw.indexOf(asciiHelper.space);
    var fmt = raw.sublist(0, x);

    // Read and validate object size
    var y = raw.indexOf(0x0, x);
    var size = int.parse(ascii.decode(raw.sublist(x, y)));
    if (size != (raw.length - y - 1)) {
      throw Exception('Malformed object $filePath: bad length');
    }

    var fmtStr = ascii.decode(fmt);
    return createObject(fmtStr, raw.sublist(y + 1), filePath);
  }

  Future<GitHash> writeObject(GitObject obj) async {
    var result = obj.serialize();
    var hash = GitHash.compute(result);
    var sha = hash.toString();

    var path = p.join(gitDir, 'objects', sha.substring(0, 2), sha.substring(2));
    await fs.directory(p.dirname(path)).create(recursive: true);
    await fs.file(path).writeAsBytes(zlib.encode(result));

    return hash;
  }

  // Look for loose objects
  // Load all pack-files indexes and look into them
  // Maybe have a refresh() method?
}
