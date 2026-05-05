import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/utils/git_file_stat.dart';

extension Index on GitRepository {
  void add(String pathSpec) {
    pathSpec = normalizePath(pathSpec);

    var index = indexStorage.readIndex();

    var filePath = p.join(workTree, pathSpec);
    var stat = fs.statSync(filePath);
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

    var stat = _statForIndex(filePath);
    if (stat == null) {
      throw GitFileNotFound(filePath);
    }

    var pathSpec = filePath;
    if (pathSpec.startsWith(workTree)) {
      pathSpec = filePath.substring(workTree.length);
    }
    // LB: Wait is this a linear search over all files??
    //     Maybe... but omitting it fully does not speed things up.
    var ei = index.entries.indexWhere((e) => e.path == pathSpec);
    if (ei != -1) {
      var entry = index.entries[ei];
      var sameCTime = true;
      if (_isComparableTime(entry.cTime, stat.cTime)) {
        sameCTime = entry.cTime.isAtSameMomentAs(stat.cTime);
      }

      var sameINode = true;
      if (_isComparableInt(entry.ino, stat.ino)) {
        sameINode = entry.ino == stat.ino;
      }

      var sameDev = true;
      if (_isComparableInt(entry.dev, stat.dev)) {
        sameDev = entry.dev == stat.dev;
      }

      if (sameCTime &&
          entry.mTime.isAtSameMomentAs(stat.mTime) &&
          sameINode &&
          sameDev &&
          entry.fileSize == stat.fileSize) {
        // We assume it is the same file.
        return entry;
      }
    }

    var data = fs.file(filePath).readAsBytesSync();
    var blob = GitBlob(data, null); // Hash the file (takes time!)
    var hash = objStorage.writeObject(blob);

    // Existing file
    if (ei != -1) {
      assert(data.length == stat.fileSize);

      var path = index.entries[ei].path;
      var newEntry = GitIndexEntry.fromFS(path, stat, hash);
      index.entries[ei] = newEntry;
      return newEntry;
    }

    // New file
    var entry = GitIndexEntry.fromFS(pathSpec, stat, hash);
    index.entries.add(entry);
    return entry;
  }

  void addDirectoryToIndex(
    GitIndex index,
    String dirPath, {
    bool recursive = false,
  }) {
    dirPath = normalizePath(dirPath);

    var dirPathSpec = toPathSpec(dirPath);
    if (dirPathSpec.isNotEmpty && !dirPathSpec.endsWith(p.separator)) {
      dirPathSpec += p.separator;
    }
    var seenPathSpecs = <String>{};

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

      seenPathSpecs.add(toPathSpec(normalizePath(fsEntity.path)));
      addFileToIndex(index, fsEntity.path);
    }

    index.entries.removeWhere((entry) {
      var path = entry.path;
      var isUnderDir =
          dirPathSpec.isEmpty ? true : path.startsWith(dirPathSpec);
      return isUnderDir && !seenPathSpecs.contains(path);
    });

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

  GitFileStat? _statForIndex(String filePath) {
    var stat = fs.statSync(filePath);
    if (stat.type == FileSystemEntityType.notFound) {
      return null;
    }
    return GitFileStat.fromFileStat(stat);
  }

  bool _isComparableTime(DateTime storedValue, DateTime currentValue) {
    return storedValue.millisecondsSinceEpoch != 0 &&
        currentValue.millisecondsSinceEpoch != 0;
  }

  bool _isComparableInt(int storedValue, int currentValue) {
    return storedValue != 0 && currentValue != 0;
  }
}
