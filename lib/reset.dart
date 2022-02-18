import 'package:path/path.dart' as p;

import 'package:dart_git/diff_commit.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'git.dart';

import 'package:dart_git/utils/file_extensions.dart'
    if (dart.library.html) 'package:dart_git/utils/file_extensions_na.dart';

extension Reset on GitRepository {
  Result<void> _resetHard(GitHash hash) {
    var headCommit = this.headCommit().getOrThrow();
    var toCommit = objStorage.readCommit(hash).getOrThrow();

    var changes = diffCommits(
      fromCommit: headCommit,
      toCommit: toCommit,
      objStore: objStorage,
    ).getOrThrow();

    for (var change in changes.add) {
      var obj = objStorage.readBlob(change.hash).getOrThrow();
      var path = p.join(workTree, change.path);

      fs.directory(p.dirname(path)).createSync(recursive: true);
      fs.file(path).writeAsBytesSync(obj.blobData);
      fs.file(path).chmodSync(change.mode.val);
    }

    for (var change in changes.remove) {
      var path = p.join(workTree, change.path);
      var file = fs.file(path);
      if (file.existsSync()) {
        var _ = file.deleteSync(recursive: true);
      }

      deleteEmptyDirectories(fs, workTree, change.path);
    }

    for (var change in changes.modify) {
      var obj = objStorage.readBlob(change.to!.hash).getOrThrow();
      var path = p.join(workTree, change.to!.path);

      fs.directory(p.dirname(path)).createSync(recursive: true);
      fs.file(path).writeAsBytesSync(obj.blobData);
      fs.file(path).chmodSync(change.to!.mode.val);
    }

    // Make the current branch point towards 'hash'
    var headRef = head().getOrThrow();
    var branchNameRef = headRef.target!;
    assert(branchNameRef.isBranch());

    var newRef = Reference.hash(branchNameRef, hash);
    refStorage.saveRef(newRef).throwOnError();

    // Redo the index
    var _ = checkout('.').getOrThrow();

    return Result(null);
  }

  Result<void> resetHard(GitHash hash) => catchAllSync(() => _resetHard(hash));
}
