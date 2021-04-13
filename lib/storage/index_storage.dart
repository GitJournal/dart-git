import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/plumbing/index.dart';

class IndexStorage {
  final String gitDir;
  final FileSystem fs;

  IndexStorage(this.gitDir, this.fs);

  Future<GitIndex> readIndex() async {
    var file = fs.file(p.join(gitDir, 'index'));
    if (!file.existsSync()) {
      return GitIndex(versionNo: 2);
    }

    // FIXME: What if reading this file fails cause of permission issues?
    return GitIndex.decode(await file.readAsBytes());
  }

  Future<void> writeIndex(GitIndex index) async {
    var path = p.join(gitDir, 'index.new');
    var file = fs.file(path);
    await file.writeAsBytes(index.serialize());
    await file.rename(p.join(gitDir, 'index'));
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
