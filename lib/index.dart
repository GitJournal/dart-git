import 'package:collection/collection.dart' show IterableExtension;
import 'package:file/file.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/blob.dart';

extension Index on GitRepository {
  Future<Result<void>> add(String pathSpec) async {
    pathSpec = normalizePath(pathSpec);

    var indexR = await indexStorage.readIndex();
    if (indexR.failed) {
      return fail(indexR);
    }
    var index = indexR.get();

    var stat = await fs.stat(pathSpec);
    if (stat.type == FileSystemEntityType.file) {
      var result = await addFileToIndex(index, pathSpec);
      if (result.failed) {
        return fail(result);
      }
    } else if (stat.type == FileSystemEntityType.directory) {
      var result = await addDirectoryToIndex(index, pathSpec, recursive: true);
      if (result.failed) {
        return fail(result);
      }
    } else {
      var ex = InvalidFileType(pathSpec);
      return Result.fail(ex);
    }

    return indexStorage.writeIndex(index);
  }

  Future<Result<GitIndexEntry>> addFileToIndex(
    GitIndex index,
    String filePath,
  ) async {
    filePath = normalizePath(filePath);

    var file = fs.file(filePath);
    if (!file.existsSync()) {
      var ex = GitFileNotFound(filePath);
      return Result.fail(ex);
    }

    // Save that file as a blob
    var data = await file.readAsBytes();
    var blob = GitBlob(data, null);
    var hashR = await objStorage.writeObject(blob);
    if (hashR.failed) {
      return fail(hashR);
    }
    var hash = hashR.get();

    var pathSpec = filePath;
    if (pathSpec.startsWith(workTree)) {
      pathSpec = filePath.substring(workTree.length);
    }

    // Add it to the index
    var entry = index.entries.firstWhereOrNull((e) => e.path == pathSpec);
    var stat = await FileStat.stat(filePath);

    // Existing file
    if (entry != null) {
      entry.hash = hash;
      entry.fileSize = data.length;
      assert(data.length == stat.size);

      entry.cTime = stat.changed;
      entry.mTime = stat.modified;
      return Result(entry);
    }

    // New file
    entry = GitIndexEntry.fromFS(pathSpec, stat, hash);
    index.entries.add(entry);
    return Result(entry);
  }

  Future<Result<void>> addDirectoryToIndex(
    GitIndex index,
    String dirPath, {
    bool recursive = false,
  }) async {
    dirPath = normalizePath(dirPath);

    var dir = fs.directory(dirPath);
    await for (var fsEntity
        in dir.list(recursive: recursive, followLinks: false)) {
      if (fsEntity.path.startsWith(gitDir)) {
        continue;
      }
      var stat = await fsEntity.stat();
      if (stat.type != FileSystemEntityType.file) {
        continue;
      }

      var r = await addFileToIndex(index, fsEntity.path);
      if (r.failed) {
        return fail(r);
      }
    }

    return Result(null);
  }

  Future<Result<void>> rm(String pathSpec, {bool rmFromFs = true}) async {
    pathSpec = normalizePath(pathSpec);

    var indexR = await indexStorage.readIndex();
    if (indexR.failed) {
      return fail(indexR);
    }
    var index = indexR.get();

    var stat = await fs.stat(pathSpec);
    if (stat.type == FileSystemEntityType.file) {
      var r = await rmFileFromIndex(index, pathSpec);
      if (r.failed) {
        return fail(r);
      }
      if (rmFromFs) {
        await fs.file(pathSpec).delete();
      }
    } else if (stat.type == FileSystemEntityType.directory) {
      var r = await rmDirectoryFromIndex(index, pathSpec, recursive: true);
      if (r.failed) {
        return fail(r);
      }
      if (rmFromFs) {
        await fs.directory(pathSpec).delete(recursive: true);
      }
    } else {
      var ex = InvalidFileType(pathSpec);
      return Result.fail(ex);
    }

    return indexStorage.writeIndex(index);
  }

  Future<Result<GitHash>> rmFileFromIndex(
    GitIndex index,
    String filePath,
  ) async {
    var pathSpec = toPathSpec(normalizePath(filePath));
    var hash = index.removePath(pathSpec);
    if (hash == null) {
      var ex = GitNotFound();
      return Result.fail(ex);
    }
    return Result(hash);
  }

  Future<Result<void>> rmDirectoryFromIndex(
    GitIndex index,
    String dirPath, {
    bool recursive = false,
  }) async {
    dirPath = normalizePath(dirPath);

    var dir = fs.directory(dirPath);
    await for (var fsEntity in dir.list(
      recursive: recursive,
      followLinks: false,
    )) {
      if (fsEntity.path.startsWith(gitDir)) {
        continue;
      }
      var stat = await fsEntity.stat();
      if (stat.type != FileSystemEntityType.file) {
        continue;
      }

      var r = await rmFileFromIndex(index, fsEntity.path);
      if (r.failed) {
        return fail(r);
      }
    }

    return Result(null);
  }
}
