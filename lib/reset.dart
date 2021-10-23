import 'package:path/path.dart' as p;

import 'package:dart_git/diff_commit.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'git.dart';

import 'package:dart_git/utils/file_extensions.dart'
    if (dart.library.html) 'package:dart_git/utils/file_extensions_na.dart';

extension Reset on GitRepository {
  Future<Result<void>> _resetHard(GitHash hash) async {
    var headCommit = await this.headCommit().getOrThrow();
    var toCommit = await objStorage.readCommit(hash).getOrThrow();

    var changes = await diffCommits(
      fromCommit: headCommit,
      toCommit: toCommit,
      objStore: objStorage,
    ).getOrThrow();

    for (var change in changes.added) {
      var obj = await objStorage.readBlob(change.hash).getOrThrow();
      var path = p.join(workTree, change.path);

      dynamic _;
      _ = await fs.directory(p.dirname(path)).create(recursive: true);
      _ = await fs.file(path).writeAsBytes(obj.blobData);
      await fs.file(path).chmod(change.mode.val);
    }

    for (var change in changes.removed) {
      var path = p.join(workTree, change.path);
      var _ = await fs.file(path).delete(recursive: true);

      await deleteEmptyDirectories(fs, workTree, change.path);
    }

    for (var change in changes.modified) {
      var obj = await objStorage.readBlob(change.to!.hash).getOrThrow();
      var path = p.join(workTree, change.to!.path);

      dynamic _;
      _ = await fs.directory(p.dirname(path)).create(recursive: true);
      _ = await fs.file(path).writeAsBytes(obj.blobData);
      await fs.file(path).chmod(change.to!.mode.val);
    }

    // Make the current branch point towards 'hash'
    var headRef = await head().getOrThrow();
    var branchNameRef = headRef.target!;
    assert(branchNameRef.isBranch());

    var newRef = Reference.hash(branchNameRef, hash);
    await refStorage.saveRef(newRef).throwOnError();

    // Redo the index
    var _ = await checkout('.').getOrThrow();

    return Result(null);
  }

  Future<Result<void>> resetHard(GitHash hash) =>
      catchAll(() => _resetHard(hash));
}
