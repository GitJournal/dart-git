import 'package:dart_git/exceptions.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/diff_commit.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'git.dart';

import 'package:dart_git/utils/file_extensions.dart'
    if (dart.library.html) 'package:dart_git/utils/file_extensions_na.dart';

extension Reset on GitRepository {
  void resetHard(GitHash hash) {
    var headCommit = this.headCommit();
    var toCommit = objStorage.readCommit(hash);

    var changes = diffCommits(
      fromCommit: headCommit,
      toCommit: toCommit,
      objStore: objStorage,
    );

    for (var change in changes.add) {
      var obj = objStorage.readBlob(change.hash);
      var path = p.join(workTree, change.path);

      fs.directory(p.dirname(path)).createSync(recursive: true);
      fs.file(path).writeAsBytesSync(obj.blobData);
      fs.file(path).chmodSync(change.mode.val);
    }

    for (var change in changes.remove) {
      var path = p.join(workTree, change.path);
      var file = fs.file(path);
      if (file.existsSync()) {
        file.deleteSync(recursive: true);
      }

      deleteEmptyDirectories(fs, workTree, change.path);
    }

    for (var change in changes.modify) {
      var obj = objStorage.readBlob(change.to!.hash);
      var path = p.join(workTree, change.to!.path);

      fs.directory(p.dirname(path)).createSync(recursive: true);
      fs.file(path).writeAsBytesSync(obj.blobData);
      fs.file(path).chmodSync(change.to!.mode.val);
    }

    // Make the current branch point towards 'hash'
    var headRef = head();
    switch (headRef) {
      case HashReference():
        throw GitHeadDetached();
      case SymbolicReference():
        var branchNameRef = headRef.target;
        assert(branchNameRef.isBranch());

        var newRef = HashReference(branchNameRef, hash);
        refStorage.saveRef(newRef);

        // Redo the index
        checkout('.');
    }
  }
}
