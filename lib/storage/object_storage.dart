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
  final String gitDir;
  final FileSystem fs;

  DateTime? _packDirChanged;
  DateTime? _packDirModified;
  var packFiles = <PackFile>[];

  ObjectStorage(this.gitDir, this.fs);

  // FIXME: Handle all fs exceptions
  // TODO: Add convenience functions to fetch a Blob/Commit/etc
  Future<GitObjectResult> read(GitHash hash) async {
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

      var bytes = await fs.file(fsEntity.path).readAsBytes();
      var idxFile = IdxFile.decode(bytes);

      var packFilePath = fsEntity.path;
      packFilePath = packFilePath.substring(0, packFilePath.lastIndexOf('.'));
      packFilePath += '.pack';

      var packFile = await PackFile.fromFile(idxFile, packFilePath);
      packFiles.add(packFile);
    }
  }

  Future<GitObjectResult> readObjectFromPath(String filePath) async {
    // FIXME: Handle zlib and fs exceptions
    var contents = await fs.file(filePath).readAsBytes();
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
    // FIXME: Avoid this copy?
    var rawData = Uint8List.fromList(raw.sublistView(y + 1));
    return createObject(fmtStr, rawData, filePath);
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

  Future<GitObject?> refSpec(GitTree tree, String spec) async {
    assert(!spec.startsWith(p.separator));
    if (spec.isEmpty) {
      return tree;
    }

    var parts = splitPath(spec);
    var name = parts.item1;
    var remainingName = parts.item2;

    for (var leaf in tree.entries) {
      if (leaf.name == name) {
        var result = await read(leaf.hash);
        // FIXME: Do not use .get()
        var obj = result.get();
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

class GitObjectResult extends Result<GitObject> {
  GitObjectResult(GitObject? s, {GitException? error}) : super(s, error: error);
  GitObjectResult.fail(GitException f) : super.fail(f);
  // GitObjectResult.catchAll(GitObject Function() catchFn) : super(catchFn);
}

class GitBlobResult extends GitObjectResult {
  GitBlobResult(GitObjectResult res)
      : super(res.success, error: res.error as GitException?);

  @override
  GitBlob get() => super.get() as GitBlob;
}

class GitTreeResult extends GitObjectResult {
  GitTreeResult(GitObjectResult res)
      : super(res.success, error: res.error as GitException?);

  @override
  GitTree get() => super.get() as GitTree;
}

class GitCommitResult extends GitObjectResult {
  GitCommitResult(GitObjectResult res)
      : super(res.success, error: res.error as GitException?);

  @override
  GitCommit get() => super.get() as GitCommit;
}
