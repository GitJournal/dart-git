import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/ascii_helper.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/idx_file.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/pack_file.dart';
import 'package:dart_git/utils.dart';
import 'package:dart_git/utils/result.dart';
import 'package:dart_git/utils/uint8list.dart';

class ObjectStorage {
  final String _gitDir;
  final FileSystem _fs;

  DateTime? _packDirChanged;
  DateTime? _packDirModified;
  var _packFiles = <PackFile>[];

  ObjectStorage(this._gitDir, this._fs);

  Future<GitObjectResult> read(GitHash hash) async {
    var sha = hash.toString();
    var path =
        p.join(_gitDir, 'objects', sha.substring(0, 2), sha.substring(2));
    if (await _fs.isFile(path)) {
      return readObjectFromPath(path);
    }

    // Read all the index files
    var packDirPath = p.join(_gitDir, 'objects', 'pack');
    var stat = await _fs.stat(packDirPath);
    if (stat.changed != _packDirChanged || stat.modified != _packDirModified) {
      await _loadPackFiles(packDirPath);

      _packDirChanged = stat.changed;
      _packDirModified = stat.modified;
    }

    for (var packFile in _packFiles) {
      var obj = await packFile.object(hash);
      if (obj != null) {
        return GitObjectResult(obj);
      }
    }

    return GitObjectResult.fail(GitObjectNotFound(hash));
  }

  Future<GitBlobResult> readBlob(GitHash hash) async =>
      GitBlobResult(await read(hash));

  Future<GitTreeResult> readTree(GitHash hash) async =>
      GitTreeResult(await read(hash));

  Future<GitCommitResult> readCommit(GitHash hash) async =>
      GitCommitResult(await read(hash));

  Future<void> _loadPackFiles(String packDirPath) async {
    _packFiles = [];

    var fileStream = _fs.directory(packDirPath).list(followLinks: false);
    await for (var fsEntity in fileStream) {
      var st = await fsEntity.stat();
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

      var packFile = await PackFile.fromFile(idxFile, packFilePath);
      _packFiles.add(packFile);
    }
  }

  // FIXME: This method should not be public
  Future<GitObjectResult> readObjectFromPath(String filePath) async {
    // FIXME: Handle zlib and fs exceptions
    var contents = await _fs.file(filePath).readAsBytes();
    var raw = zlib.decode(contents) as Uint8List;

    // Read Object Type
    var x = raw.indexOf(asciiHelper.space);
    if (x == -1) {
      return GitObjectResult.fail(GitObjectCorruptedMissingType());
    }
    var fmt = raw.sublistView(0, x);

    // Read and validate object size
    var y = raw.indexOf(0x0, x);
    if (y == -1) {
      return GitObjectResult.fail(GitObjectCorruptedMissingSize());
    }

    var size = int.tryParse(ascii.decode(raw.sublistView(x, y)));
    if (size == null) {
      return GitObjectResult.fail(GitObjectCorruptedInvalidIntSize());
    }

    if (size != (raw.length - y - 1)) {
      return GitObjectResult.fail(GitObjectCorruptedBadSize());
    }

    var fmtStr = ascii.decode(fmt);
    var rawData = raw.sublistView(y + 1);
    return createObject(fmtStr, rawData, filePath);
  }

  Future<GitHash> writeObject(GitObject obj) async {
    var result = obj.serialize();
    var hash = GitHash.compute(result);
    var sha = hash.toString();

    var path =
        p.join(_gitDir, 'objects', sha.substring(0, 2), sha.substring(2));
    await _fs.directory(p.dirname(path)).create(recursive: true);

    var exists = await _fs.isFile(path);
    if (exists) {
      return hash;
    }
    var file = await _fs.file(path).open(mode: FileMode.writeOnly);
    await file.writeFrom(zlib.encode(result));
    await file.close();

    return hash;
  }

  Future<GitObjectResult> refSpec(GitTree tree, String spec) async {
    assert(!spec.startsWith(p.separator));

    if (spec.isEmpty) {
      return GitObjectResult(tree);
    }

    var parts = splitPath(spec);
    var name = parts.item1;
    var remainingName = parts.item2;

    for (var leaf in tree.entries) {
      if (leaf.name == name) {
        var result = await read(leaf.hash);
        var obj = result.get();

        if (remainingName.isEmpty) {
          return GitObjectResult(obj);
        }

        if (obj is GitTree) {
          return refSpec(obj, remainingName);
        } else {
          return GitObjectResult.fail(
            GitObjectWithRefSpecNotFound(spec),
          );
        }
      }
    }
    return GitObjectResult.fail(
      GitObjectWithRefSpecNotFound(spec),
    );
  }
}

//
// FIXME: Once Dart has typedefs for classes, this code can be removed
//
class GitObjectResult extends Result<GitObject> {
  GitObjectResult(GitObject? s, {GitException? error}) : super(s, error: error);
  GitObjectResult.fail(Exception f) : super.fail(f);

  static Future<GitObjectResult> catchAll(
      Future<GitObjectResult> Function() catchFn) async {
    try {
      return catchFn();
    } on Exception catch (e) {
      return GitObjectResult.fail(e);
    }
  }
}

class GitBlobResult extends GitObjectResult {
  GitBlobResult(GitObjectResult res)
      : super(res.success, error: res.error as GitException?);
  GitBlobResult.fail(Exception f) : super.fail(f);

  @override
  GitBlob get() => super.get() as GitBlob;

  static Future<GitBlobResult> catchAll(
      Future<GitBlobResult> Function() catchFn) async {
    try {
      return catchFn();
    } on Exception catch (e) {
      return GitBlobResult.fail(e);
    }
  }
}

class GitTreeResult extends GitObjectResult {
  GitTreeResult(GitObjectResult res)
      : super(res.success, error: res.error as GitException?);
  GitTreeResult.fail(Exception f) : super.fail(f);

  @override
  GitTree get() => super.get() as GitTree;

  static Future<GitTreeResult> catchAll(
      Future<GitTreeResult> Function() catchFn) async {
    try {
      return catchFn();
    } on Exception catch (e) {
      return GitTreeResult.fail(e);
    }
  }
}

class GitCommitResult extends GitObjectResult {
  GitCommitResult(GitObjectResult res)
      : super(res.success, error: res.error as GitException?);
  GitCommitResult.fail(Exception f) : super.fail(f);

  @override
  GitCommit get() => super.get() as GitCommit;

  static Future<GitCommitResult> catchAll(
      Future<GitCommitResult> Function() catchFn) async {
    try {
      return catchFn();
    } on Exception catch (e) {
      return GitCommitResult.fail(e);
    }
  }
}
