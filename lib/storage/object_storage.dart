import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/ascii_helper.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/idx_file.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/pack_file.dart';
import 'package:dart_git/utils.dart';

class ObjectStorage {
  final String gitDir;
  final FileSystem fs;

  DateTime _packDirChanged;
  DateTime _packDirModified;
  var packFiles = <PackFile>[];

  ObjectStorage(this.gitDir, this.fs);

  Future<GitObject> readObjectFromHash(GitHash hash) async {
    var sha = hash.toString();
    var path = p.join(gitDir, 'objects', sha.substring(0, 2), sha.substring(2));
    if (await fs.isFile(path)) {
      return readObjectFromPath(path);
    }

    // Read all the index files
    var packDirPath = p.join(gitDir, 'objects', 'pack');
    var stat = await fs.stat(packDirPath);
    if (stat.changed != _packDirChanged || stat.modified != _packDirModified) {
      await _loadPackFiles(packDirPath);

      _packDirChanged = stat.changed;
      _packDirModified = stat.modified;
    }

    for (var packFile in packFiles) {
      var obj = packFile.object(hash);
      if (obj != null) {
        return obj;
      }
    }

    return null;
  }

  Future<void> _loadPackFiles(String packDirPath) async {
    packFiles = [];

    var fileStream = fs.directory(packDirPath).list(followLinks: false);
    await for (var fsEntity in fileStream) {
      var st = await fsEntity.stat();
      if (st.type != FileSystemEntityType.file) {
        continue;
      }
      if (!fsEntity.path.endsWith('.idx')) {
        continue;
      }

      var bytes = await fs.file(fsEntity).readAsBytes();
      var idxFile = IdxFile.decode(bytes);

      var packFilePath = fsEntity.path;
      packFilePath = packFilePath.substring(0, packFilePath.lastIndexOf('.'));
      packFilePath += '.pack';

      var packFile = await PackFile.fromFile(idxFile, packFilePath);
      packFiles.add(packFile);
    }
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

    var exists = await fs.isFile(path);
    if (exists) {
      return hash;
    }
    var file = await fs.file(path).open(mode: FileMode.writeOnly);
    await file.writeFrom(zlib.encode(result));
    await file.close();

    return hash;
  }

  Future<GitObject> refSpec(GitTree tree, String spec) async {
    assert(!spec.startsWith(p.separator));
    if (spec.isEmpty) {
      return tree;
    }

    var parts = splitPath(spec);
    var name = parts.item1;
    var remainingName = parts.item2;

    for (var leaf in tree.entries) {
      if (leaf.path == name) {
        var obj = await readObjectFromHash(leaf.hash);
        if (remainingName.isEmpty) {
          return obj;
        }

        if (obj is GitTree) {
          return refSpec(obj, remainingName);
        } else {
          return null;
        }
      }
    }
    return null;
  }
}
