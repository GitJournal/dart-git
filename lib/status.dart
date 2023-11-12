import 'package:collection/collection.dart';
import 'package:file/file.dart';

import 'package:dart_git/dart_git.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/utils/file_mode.dart';

/*
StatusSummary {
  not_added: [
    'assets/README',
    'assets/folder-green-git-icon.png',
    'assets/folder-green-git-icon.svg',
    'todo.md'
  ],
  conflicted: [],
  created: [],
  deleted: [],
  modified: [],
  renamed: [],
  files: [
    FileStatusSummary {
      path: 'assets/README',
      index: '?',
      working_dir: '?'
    },
    FileStatusSummary {
      path: 'assets/folder-green-git-icon.png',
      index: '?',
      working_dir: '?'
    },
    FileStatusSummary {
      path: 'assets/folder-green-git-icon.svg',
      index: '?',
      working_dir: '?'
    },
    FileStatusSummary { path: 'todo.md', index: '?', working_dir: '?' }
  ],
  staged: [],
  ahead: 0,
  behind: 0,
  current: 'master',
  tracking: null
}
*/

// FIXME: Give me the oids as well
class GitStatusResult {
  var added = <String>[];
  var removed = <String>[]; // I want the oids
  var modified = <String>[]; // I want the oids
  var unTracked = <String>[];

  void add(GitStatusResult r) {
    added.addAll(r.added);
    removed.addAll(r.removed);
    modified.addAll(r.modified);
    unTracked.addAll(r.unTracked);
  }
}

extension Status on GitRepository {
  GitStatusResult status() {
    var rootTreeR = headTree();
    var result = GitStatusResult();
    return _status(rootTreeR, workTree, result);
  }

  // FIXME: vHanda: Return unchanged stuff
  GitStatusResult _status(
    GitTree tree,
    String? treePath,
    GitStatusResult result,
  ) {
    var dirContents = fs.directory(treePath).listSync(followLinks: false);
    var newFilesAdded = dirContents.map((e) => e.path).toSet();

    for (var entry in tree.entries) {
      var fsEntity = dirContents.firstWhereOrNull(
        (e) => e.basename == entry.name,
      );
      if (fsEntity == null) {
        result.removed.add(fsEntity!.path);
        continue;
      }

      newFilesAdded.remove(fsEntity.path);

      if (_ignoreEntity(fsEntity)) {
        continue;
      }

      if (entry.mode != GitFileMode.Dir) {
        if (_fileModified(fsEntity, entry)) {
          result.modified.add(fsEntity.path);
        }
        continue;
      }

      var subTree = objStorage.readTree(entry.hash);
      var r = _status(subTree, fsEntity.path, result);
      result.add(r);
    }

    result.added.addAll(newFilesAdded);
    return result;
  }

  bool _fileModified(FileSystemEntity fsEntity, GitTreeEntry treeEntry) {
    // Most expensive way is to compute the hash
    // FIXME: I could use the index entry to figure this out?
    return false;
  }

  bool _ignoreEntity(FileSystemEntity fsEntity) {
    return fsEntity.basename == '.git';
  }
}

// * Add a simple test for this
// * Look at the interface of go-git

// libGit2 takes a lot of status parameters
// and returns a diff of (Head to Index) and (Index to WorkTree)

// go-git has
/*

// StatusCode status code of a file in the Worktree
type StatusCode byte

const (
	Unmodified         StatusCode = ' '
	Untracked          StatusCode = '?'
	Modified           StatusCode = 'M'
	Added              StatusCode = 'A'
	Deleted            StatusCode = 'D'
	Renamed            StatusCode = 'R'
	Copied             StatusCode = 'C'
	UpdatedButUnmerged StatusCode = 'U'
)


go-git returns the staging area and workTree status code of each file
It uses a merkletrie to do the diff. What is this?

*/
