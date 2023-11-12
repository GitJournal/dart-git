import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/plumbing/index.dart';

import 'interfaces.dart';

class IndexStorageFS implements IndexStorage {
  final String _gitDir;
  final FileSystem _fs;

  IndexStorageFS(this._gitDir, this._fs);

  @override
  GitIndex readIndex() {
    var file = _fs.file(p.join(_gitDir, 'index'));
    if (!file.existsSync()) {
      return GitIndex(versionNo: 2);
    }

    return GitIndex.decode(file.readAsBytesSync());
  }

  @override
  void writeIndex(GitIndex index) {
    var path = p.join(_gitDir, 'index.new');
    var file = _fs.file(path);

    file.writeAsBytesSync(index.serialize());
    file.renameSync(p.join(_gitDir, 'index'));

    return;
  }

  @override
  void close() {}
}

// Where do I put all the index operations which modify the index?

// Arguably on the index object, no?
// addFile(filePath, hash)
// addOrUpdateFile()
// rmFile()
// addDirectory()

// This Index Storage isn't needed in the GitHub provider!
// and therefore the entire thing is made much simpler in some ways
