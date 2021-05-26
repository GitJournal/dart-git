import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/utils/result.dart';

class IndexStorage {
  final String _gitDir;
  final FileSystem _fs;

  IndexStorage(this._gitDir, this._fs);

  Future<Result<GitIndex>> readIndex() async {
    var file = _fs.file(p.join(_gitDir, 'index'));
    if (!file.existsSync()) {
      var index = GitIndex(versionNo: 2);
      return Result(index);
    }

    var index = GitIndex.decode(await file.readAsBytes());
    return Result(index);
  }

  Future<Result<void>> writeIndex(GitIndex index) async {
    var path = p.join(_gitDir, 'index.new');
    var file = _fs.file(path);
    await file.writeAsBytes(index.serialize());
    await file.rename(p.join(_gitDir, 'index'));

    return Result(null);
  }
}

// Where do I put all the index operations which modify the index?

// Arguably on the index object, no?
// addFile(filePath, hash)
// addOrUpdateFile()
// rmFile()
// addDirectory()

// This Index Storage isn't needed in the GitHub provider!
// and therefore the entire thing is made much simpler in some ways
