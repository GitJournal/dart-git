import 'package:collection/collection.dart' show IterableExtension;
import 'package:file/file.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/blob.dart';

extension Index on GitRepository {
  Result<void> add(String pathSpec) {
    pathSpec = normalizePath(pathSpec);

    var indexR = indexStorage.readIndex();
    if (indexR.isFailure) {
      return fail(indexR);
    }
    var index = indexR.getOrThrow();

    var stat = fs.statSync(pathSpec);
    if (stat.type == FileSystemEntityType.file) {
      var result = addFileToIndex(index, pathSpec);
      if (result.isFailure) {
        return fail(result);
      }
    } else if (stat.type == FileSystemEntityType.directory) {
      var result = addDirectoryToIndex(index, pathSpec, recursive: true);
      if (result.isFailure) {
        return fail(result);
      }
    } else {
      var ex = InvalidFileType(pathSpec);
      return Result.fail(ex);
    }

    return indexStorage.writeIndex(index);
  }

  Result<GitIndexEntry> addFileToIndex(
    GitIndex index,
    String filePath,
  ) {
    filePath = normalizePath(filePath);

    var file = fs.file(filePath);
    if (!file.existsSync()) {
      var ex = GitFileNotFound(filePath);
      return Result.fail(ex);
    }

    // Save that file as a blob
    var data = file.readAsBytesSync();
    var blob = GitBlob(data, null);
    var hashR = objStorage.writeObject(blob);
    if (hashR.isFailure) {
      return fail(hashR);
    }
    var hash = hashR.getOrThrow();

    var pathSpec = filePath;
    if (pathSpec.startsWith(workTree)) {
      pathSpec = filePath.substring(workTree.length);
    }

    // Add it to the index
    var entry = index.entries.firstWhereOrNull((e) => e.path == pathSpec);
    var stat = FileStat.statSync(filePath);

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

  Result<void> addDirectoryToIndex(
    GitIndex index,
    String dirPath, {
    bool recursive = false,
  }) {
    dirPath = normalizePath(dirPath);

    var dir = fs.directory(dirPath);
    for (var fsEntity
        in dir.listSync(recursive: recursive, followLinks: false)) {
      if (fsEntity.path.startsWith(gitDir)) {
        continue;
      }
      var stat = fsEntity.statSync();
      if (stat.type != FileSystemEntityType.file) {
        continue;
      }

      var r = addFileToIndex(index, fsEntity.path);
      if (r.isFailure) {
        return fail(r);
      }
    }

    return Result(null);
  }

  Result<void> rm(String pathSpec, {bool rmFromFs = true}) {
    pathSpec = normalizePath(pathSpec);

    var indexR = indexStorage.readIndex();
    if (indexR.isFailure) {
      return fail(indexR);
    }
    var index = indexR.getOrThrow();

    var stat = fs.statSync(pathSpec);
    if (stat.type == FileSystemEntityType.file) {
      var r = rmFileFromIndex(index, pathSpec);
      if (r.isFailure) {
        return fail(r);
      }
      if (rmFromFs) {
        fs.file(pathSpec).deleteSync();
      }
    } else if (stat.type == FileSystemEntityType.directory) {
      var r = rmDirectoryFromIndex(index, pathSpec, recursive: true);
      if (r.isFailure) {
        return fail(r);
      }
      if (rmFromFs) {
        fs.directory(pathSpec).deleteSync(recursive: true);
      }
    } else {
      var ex = InvalidFileType(pathSpec);
      return Result.fail(ex);
    }

    return indexStorage.writeIndex(index);
  }

  Result<GitHash> rmFileFromIndex(
    GitIndex index,
    String filePath,
  ) {
    var pathSpec = toPathSpec(normalizePath(filePath));
    var hash = index.removePath(pathSpec);
    if (hash == null) {
      var ex = GitNotFound();
      return Result.fail(ex);
    }
    return Result(hash);
  }

  Result<void> rmDirectoryFromIndex(
    GitIndex index,
    String dirPath, {
    bool recursive = false,
  }) {
    dirPath = normalizePath(dirPath);

    var dir = fs.directory(dirPath);
    for (var fsEntity in dir.listSync(
      recursive: recursive,
      followLinks: false,
    )) {
      if (fsEntity.path.startsWith(gitDir)) {
        continue;
      }
      var stat = fsEntity.statSync();
      if (stat.type != FileSystemEntityType.file) {
        continue;
      }

      var r = rmFileFromIndex(index, fsEntity.path);
      if (r.isFailure) {
        return fail(r);
      }
    }

    return Result(null);
  }
}
