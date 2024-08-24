import 'package:collection/collection.dart' show IterableExtension;
import 'package:file/file.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/blob.dart';

extension Index on GitRepository {
  void add(String pathSpec) {
    pathSpec = normalizePath(pathSpec);

    var index = indexStorage.readIndex();

    var stat = fs.statSync(pathSpec);
    if (stat.type == FileSystemEntityType.file) {
      addFileToIndex(index, pathSpec);
    } else if (stat.type == FileSystemEntityType.directory) {
      addDirectoryToIndex(index, pathSpec, recursive: true);
    } else {
      throw InvalidFileType(pathSpec);
    }

    return indexStorage.writeIndex(index);
  }

  GitIndexEntry addFileToIndex(
    GitIndex index,
    String filePath,
  ) {
    filePath = normalizePath(filePath);

    var file = fs.file(filePath);
    if (!file.existsSync()) {
      throw GitFileNotFound(filePath);
    }

    var pathSpec = filePath;
    if (pathSpec.startsWith(workTree)) {
      pathSpec = filePath.substring(workTree.length);
    }
    // LB: Wait is this a linear search over all files??
    //     Maybe... but omitting it fully does not speed things up.
    var entry = index.entries.firstWhereOrNull((e) => e.path == pathSpec);
    var stat = FileStat.statSync(filePath);
    if (entry != null &&
        entry.cTime.isAtSameMomentAs(stat.changed) &&
        entry.mTime.isAtSameMomentAs(stat.modified) &&
        entry.fileSize == stat.size) {
      // We assume it is the same file.
      return entry;
    }

    var data = file.readAsBytesSync();
    var blob = GitBlob(data, null); // Hash the file (takes time!)
    var hash = objStorage.writeObject(blob);

    // Existing file
    if (entry != null) {
      assert(data.length == stat.size);

      return entry.copyWith(
        hash: hash,
        fileSize: data.length,
        cTime: stat.changed,
        mTime: stat.modified,
      );
    }

    // New file
    entry = GitIndexEntry.fromFS(pathSpec, stat, hash);
    index.entries.add(entry);
    return entry;
  }

  void addDirectoryToIndex(
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

      addFileToIndex(index, fsEntity.path);
    }

    return;
  }

  void rm(String pathSpec, {bool rmFromFs = true}) {
    pathSpec = normalizePath(pathSpec);

    var index = indexStorage.readIndex();

    var stat = fs.statSync(pathSpec);
    if (stat.type == FileSystemEntityType.file) {
      rmFileFromIndex(index, pathSpec);
      if (rmFromFs) {
        fs.file(pathSpec).deleteSync();
      }
    } else if (stat.type == FileSystemEntityType.directory) {
      rmDirectoryFromIndex(index, pathSpec, recursive: true);
      if (rmFromFs) {
        fs.directory(pathSpec).deleteSync(recursive: true);
      }
    } else {
      throw InvalidFileType(pathSpec);
    }

    return indexStorage.writeIndex(index);
  }

  GitHash rmFileFromIndex(
    GitIndex index,
    String filePath,
  ) {
    var pathSpec = toPathSpec(normalizePath(filePath));
    var hash = index.removePath(pathSpec);
    if (hash == null) {
      throw GitNotFound();
    }
    return hash;
  }

  void rmDirectoryFromIndex(
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

      rmFileFromIndex(index, fsEntity.path);
    }

    return;
  }
}
