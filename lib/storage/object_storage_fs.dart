import 'dart:convert';
import 'dart:io' show zlib;
import 'dart:typed_data';

import 'package:charcode/charcode.dart';
import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/idx_file.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/plumbing/pack_file.dart';
import 'package:dart_git/utils/result.dart';
import 'package:dart_git/utils/uint8list.dart';
import 'interfaces.dart';

class ObjectStorageFS implements ObjectStorage {
  final String _gitDir;
  final FileSystem _fs;

  DateTime? _packDirChanged;
  DateTime? _packDirModified;
  var _packFiles = <PackFile>[];

  ObjectStorageFS(this._gitDir, this._fs);

  @override
  Future<Result<GitObject>> read(GitHash hash) async {
    var sha = hash.toString();
    var path =
        p.join(_gitDir, 'objects', sha.substring(0, 2), sha.substring(2));
    if (_fs.isFileSync(path)) {
      return readObjectFromPath(path);
    }

    // Read all the index files
    var packDirPath = p.join(_gitDir, 'objects', 'pack');
    var stat = _fs.statSync(packDirPath);
    if (stat.changed != _packDirChanged || stat.modified != _packDirModified) {
      await _loadPackFiles(packDirPath);

      _packDirChanged = stat.changed;
      _packDirModified = stat.modified;
    }

    for (var packFile in _packFiles) {
      var obj = await packFile.object(hash);
      if (obj != null) {
        return Result<GitObject>(obj);
      }
    }

    return Result.fail(GitObjectNotFound(hash));
  }

  Future<void> _loadPackFiles(String packDirPath) async {
    _packFiles = [];

    var fileStream = _fs.directory(packDirPath).list(followLinks: false);
    await for (var fsEntity in fileStream) {
      var st = fsEntity.statSync();
      if (st.type != FileSystemEntityType.file) {
        continue;
      }
      if (!fsEntity.path.endsWith('.idx')) {
        continue;
      }

      var bytes = await _fs.file(fsEntity.path).readAsBytes();
      var idxFile = IdxFile.decode(bytes);

      var packFilePath = fsEntity.path;
      packFilePath = packFilePath.substring(0, packFilePath.lastIndexOf('.'));
      packFilePath += '.pack';

      var packFile = PackFile.fromFile(idxFile, packFilePath, _fs);
      _packFiles.add(packFile);
    }
  }

  // FIXME: This method should not be public
  Future<Result<GitObject>> readObjectFromPath(String filePath) async {
    // FIXME: Handle zlib and fs exceptions
    var contents = await _fs.file(filePath).readAsBytes();
    var raw = zlib.decode(contents) as Uint8List;

    // Read Object Type
    var x = raw.indexOf($space);
    if (x == -1) {
      return Result.fail(GitObjectCorruptedMissingType());
    }
    var fmt = raw.sublistView(0, x);

    // Read and validate object size
    var y = raw.indexOf(0x0, x);
    if (y == -1) {
      return Result.fail(GitObjectCorruptedMissingSize());
    }

    var size = int.tryParse(ascii.decode(raw.sublistView(x, y)));
    if (size == null) {
      return Result.fail(GitObjectCorruptedInvalidIntSize());
    }

    if (size != (raw.length - y - 1)) {
      return Result.fail(GitObjectCorruptedBadSize());
    }

    var fmtStr = ascii.decode(fmt);
    var rawData = raw.sublistView(y + 1);
    return createObject(fmtStr, rawData);
  }

  @override
  Future<Result<GitHash>> writeObject(GitObject obj) async {
    var result = obj.serialize();
    var hash = GitHash.compute(result);
    var sha = hash.toString();

    var path =
        p.join(_gitDir, 'objects', sha.substring(0, 2), sha.substring(2));
    var _ = await _fs.directory(p.dirname(path)).create(recursive: true);

    var exists = _fs.isFileSync(path);
    if (exists) {
      return Result(hash);
    }
    var file = _fs.file(path).openSync(mode: FileMode.writeOnly);
    var __ = await file.writeFrom(zlib.encode(result));
    file.closeSync();

    return Result(hash);
  }
}
