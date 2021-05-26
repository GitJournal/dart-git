import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/config.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/fs.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/storage/config_storage.dart';
import 'package:dart_git/storage/config_storage_exception_catcher.dart';
import 'package:dart_git/storage/index_storage.dart';
import 'package:dart_git/storage/index_storage_exception_catcher.dart';
import 'package:dart_git/storage/object_storage.dart';
import 'package:dart_git/storage/object_storage_exception_catcher.dart';
import 'package:dart_git/storage/reference_storage.dart';
import 'package:dart_git/storage/reference_storage_exception_catcher.dart';
import 'package:dart_git/utils/result.dart';

export 'commit.dart';
export 'checkout.dart';
export 'merge_base.dart';
export 'remotes.dart';
export 'utils/result.dart';

// A Git Repo has 5 parts -
// * Object Store
// * Ref Store
// * Index
// * Working Tree
// * Config
class GitRepository {
  late String workTree;
  late String gitDir;

  late Config config;

  FileSystem fs;
  late ReferenceStorage refStorage;
  late ObjectStorage objStorage;
  late IndexStorage indexStorage;
  late ConfigStorage configStorage;

  GitRepository._internal({required String rootDir, required this.fs}) {
    workTree = rootDir;
    if (!workTree.endsWith(p.separator)) {
      workTree += p.separator;
    }
    gitDir = p.join(workTree, '.git');
  }

  // FIXME: The FS operations could throw an error!
  static String? findRootDir(String path, {FileSystem? fs}) {
    fs ??= const LocalFileSystemWithChecks();

    while (true) {
      var gitDir = p.join(path, '.git');
      if (fs.isDirectorySync(gitDir)) {
        return path;
      }

      if (path == p.separator) {
        break;
      }

      path = p.dirname(path);
    }
    return null;
  }

  static Future<Result<GitRepository>> load(
    String gitRootDir, {
    FileSystem? fs,
  }) async {
    fs ??= const LocalFileSystemWithChecks();

    if (!(await isValidRepo(gitRootDir, fs: fs))) {
      var ex = InvalidRepoException(gitRootDir);
      return Result.fail(ex);
    }

    var repo = GitRepository._internal(rootDir: gitRootDir, fs: fs);

    repo.objStorage = ObjectStorageExceptionCatcher(
      storage: ObjectStorage(repo.gitDir, fs),
    );
    repo.refStorage = ReferenceStorageExceptionCatcher(
      storage: ReferenceStorage(repo.gitDir, fs),
    );
    repo.indexStorage = IndexStorageExceptionCatcher(
      storage: IndexStorage(repo.gitDir, fs),
    );
    repo.configStorage = ConfigStorageExceptionCatcher(
      storage: ConfigStorage(repo.gitDir, fs),
    );

    var configResult = await repo.configStorage.readConfig();
    if (configResult.failed) {
      return fail(configResult);
    }
    repo.config = configResult.get();

    return Result(repo);
  }

  static Future<bool> isValidRepo(String gitRootDir, {FileSystem? fs}) async {
    fs ??= const LocalFileSystemWithChecks();

    var isDir = await fs.isDirectory(gitRootDir);
    if (!isDir) {
      return false;
    }

    var repo = GitRepository._internal(rootDir: gitRootDir, fs: fs);
    var dotGitExists = await fs.isDirectory(repo.gitDir);
    if (!dotGitExists) {
      return false;
    }

    repo.configStorage = ConfigStorage(repo.gitDir, fs);
    var configExists = await repo.configStorage.exists().get();
    if (!configExists) {
      return false;
    }

    return true;
  }

  // FIXME: Handle FS exceptions!
  static Future<void> init(
    String path, {
    FileSystem? fs,
    String defaultBranch = 'master',
  }) async {
    fs ??= const LocalFileSystem();

    // FIXME: Check if path has stuff and accordingly return

    var gitDir = p.join(path, '.git');
    var dirsToCreate = [
      'branches',
      'objects/pack',
      'refs/heads',
      'refs/tags',
    ];
    for (var dir in dirsToCreate) {
      await fs.directory(p.join(gitDir, dir)).create(recursive: true);
    }

    await fs.file(p.join(gitDir, 'description')).writeAsString(
        "Unnamed repository; edit this file 'description' to name the repository.\n");
    await fs
        .file(p.join(gitDir, 'HEAD'))
        .writeAsString('ref: refs/heads/$defaultBranch\n');

    var config = Config('');
    var core = config.section('core');
    core.options['repositoryformatversion'] = '0';
    core.options['filemode'] = 'false';
    core.options['bare'] = 'false';

    await fs.file(p.join(gitDir, 'config')).writeAsString(config.serialize());
  }

  Future<Result<void>> saveConfig() {
    return configStorage.writeConfig(config);
  }

  Future<Result<List<String>>> branches() async {
    var refsResult = await refStorage.listReferences(refHeadPrefix);
    if (refsResult.failed) {
      return fail(refsResult);
    }

    var refs = refsResult.get();
    var refNames = refs.map((r) => r.name);
    var branchNames = refNames.map((r) => r.branchName()!).toList();

    return Result(branchNames);
  }

  Future<Result<String>> currentBranch() async {
    var headResult = await head();
    if (headResult.failed) {
      return fail(headResult);
    }

    var _head = headResult.get();
    if (_head.isHash) {
      var ex = GitHeadDetached();
      return Result.fail(ex);
    }

    var name = _head.target!.branchName();
    return Result(name);
  }

  Future<Result<BranchConfig>> setUpstreamTo(
    GitRemoteConfig remote,
    String remoteBranchName,
  ) async {
    var branchNameResult = await currentBranch();
    if (branchNameResult.failed) {
      return fail(branchNameResult);
    }

    var branchName = branchNameResult.get();
    return setBranchUpstreamTo(branchName, remote, remoteBranchName);
  }

  Future<Result<BranchConfig>> setBranchUpstreamTo(String branchName,
      GitRemoteConfig remote, String remoteBranchName) async {
    var brConfig = config.branch(branchName);
    if (brConfig == null) {
      brConfig = BranchConfig(name: branchName);
      config.branches[branchName] = brConfig;
    }
    brConfig.remote = remote.name;
    brConfig.merge = ReferenceName.branch(remoteBranchName);

    var saveR = await saveConfig();
    if (saveR.failed) {
      return fail(saveR);
    }
    return Result(brConfig);
  }

  Future<Result<GitHash>> createBranch(
    String name, {
    GitHash? hash,
    bool overwrite = false,
  }) async {
    if (hash == null) {
      var headHashResult = await headHash();
      if (headHashResult.failed) {
        return fail(headHashResult);
      }
      hash = headHashResult.get();
    }

    var branch = ReferenceName.branch(name);
    var refResult = await refStorage.reference(branch);
    if (refResult.failed && refResult.error is! GitRefNotFound) {
      return fail(refResult);
    }
    if (!overwrite && refResult.succeeded) {
      var ex = GitBranchAlreadyExists(name);
      return Result.fail(ex);
    }

    var result = await refStorage.saveRef(Reference.hash(branch, hash));
    if (result.failed) {
      return fail(result);
    }
    return Result(hash);
  }

  Future<Result<Reference>> head() async {
    var result = await refStorage.reference(ReferenceName('HEAD'));
    if (result.failed) {
      return fail(result);
    }

    return Result(result.get());
  }

  Future<Result<GitHash>> headHash() async {
    var result = await refStorage.reference(ReferenceName('HEAD'));
    if (result.failed) {
      return fail(result);
    }

    var ref = result.get();
    result = await resolveReference(ref);
    if (result.failed) {
      return fail(result);
    }

    ref = result.get();
    return Result(ref.hash!);
  }

  Future<Result<GitCommit>> headCommit() async {
    var hashResult = await headHash();
    if (hashResult.failed) {
      return fail(hashResult);
    }
    var hash = hashResult.get();

    var result = await objStorage.readCommit(hash);
    if (result.failed) {
      return fail(result);
    }
    return Result(result.get());
  }

  Future<Result<GitTree>> headTree() async {
    var commitResult = await headCommit();
    if (commitResult.failed) {
      return fail(commitResult);
    }
    var commit = commitResult.get();

    var res = await objStorage.readTree(commit.treeHash);
    if (res.failed) {
      return fail(res);
    }
    return Result(res.get());
  }

  Future<Result<Reference>> resolveReference(
    Reference ref, {
    bool recursive = true,
  }) async {
    if (ref.type == ReferenceType.Hash) {
      return Result(ref);
    }

    var resolvedRefResult = await refStorage.reference(ref.target!);
    if (resolvedRefResult.failed) {
      return fail(resolvedRefResult);
    }

    var resolvedRef = resolvedRefResult.get();
    return recursive
        ? await resolveReference(resolvedRef)
        : Result(resolvedRef);
  }

  Future<Result<Reference>> resolveReferenceName(ReferenceName refName) async {
    var resolvedRefResult = await refStorage.reference(refName);
    if (resolvedRefResult.failed) {
      return fail(resolvedRefResult);
    }

    var resolvedRef = resolvedRefResult.get();
    return resolveReference(resolvedRef);
  }

  Future<bool> canPush() async {
    if (config.remotes.isEmpty) {
      return false;
    }

    var headResult = await head();
    if (headResult.failed) {
      return false;
    }

    var _head = headResult.get();
    if (_head.isHash) {
      return false;
    }

    var brConfig = config.branch(_head.target!.branchName()!);
    var brConfigMerge = brConfig?.merge;
    var brConfigRemote = brConfig?.remote;
    if (brConfig == null || brConfigMerge == null || brConfigRemote == null) {
      // FIXME: Maybe we can push other branches!
      return false;
    }

    var resolvedHeadResult = await resolveReference(_head);
    if (resolvedHeadResult.failed) {
      return false;
    }
    var resolvedHead = resolvedHeadResult.get();

    // Construct remote's branch
    var remoteBranchName = brConfigMerge.branchName()!;
    var remoteRefName = ReferenceName.remote(brConfigRemote, remoteBranchName);
    var remoteRefResult = await resolveReferenceName(remoteRefName);
    if (remoteRefResult.failed) {
      return false;
    }
    var remoteRef = remoteRefResult.get();

    return resolvedHead.hash != remoteRef.hash;
  }

  /// Returns -1 if unreachable
  Future<Result<int>> countTillAncestor(GitHash from, GitHash ancestor) async {
    var seen = <GitHash>{};
    var parents = <GitHash>[];
    parents.add(from);
    while (parents.isNotEmpty) {
      var sha = parents[0];
      if (sha == ancestor) {
        break;
      }
      parents.removeAt(0);
      seen.add(sha);

      var commitR = await objStorage.readCommit(sha);
      if (commitR.failed) {
        return fail(commitR);
      }
      var commit = commitR.get();

      for (var p in commit.parents) {
        if (seen.contains(p)) continue;
        parents.add(p);
      }
    }

    return Result(parents.isEmpty ? -1 : seen.length);
  }

  Future<Result<int>> numChangesToPush() async {
    var head = await (this.head() as FutureOr<Reference>);
    if (head.isHash || head.target == null) {
      return Result(0);
    }

    var brConfig = config.branch(head.target!.branchName()!);
    var brConfigMerge = brConfig?.merge;
    var brConfigRemote = brConfig?.remote;
    if (brConfig == null || brConfigMerge == null || brConfigRemote == null) {
      return Result(0);
    }

    // Construct remote's branch
    var remoteBranchName = brConfigMerge.branchName()!;
    var remoteRefName = ReferenceName.remote(brConfigRemote, remoteBranchName);

    var headRefResult = await resolveReference(head);
    var remoteRefResult = await resolveReferenceName(remoteRefName);
    if (headRefResult.failed) {
      return fail(headRefResult);
    }
    if (remoteRefResult.failed) {
      return fail(remoteRefResult);
    }

    var headHash = headRefResult.get().hash;
    var remoteHash = remoteRefResult.get().hash;

    if (headHash == null || remoteHash == null) {
      return Result(0);
    }
    if (headHash == remoteHash) {
      return Result(0);
    }

    var aheadByResult = await countTillAncestor(headHash, remoteHash);
    if (aheadByResult.failed) {
      return fail(aheadByResult);
    }
    var aheadBy = aheadByResult.get();

    return Result(aheadBy != -1 ? aheadBy : 0);
  }

  Future<void> add(String pathSpec) async {
    pathSpec = normalizePath(pathSpec);

    var index = await indexStorage.readIndex().get();

    var stat = await fs.stat(pathSpec);
    if (stat.type == FileSystemEntityType.file) {
      await addFileToIndex(index, pathSpec);
    } else if (stat.type == FileSystemEntityType.directory) {
      await addDirectoryToIndex(index, pathSpec, recursive: true);
    } else {
      throw Exception('Neither file or directory');
    }

    await indexStorage.writeIndex(index);
  }

  Future<GitIndexEntry?> addFileToIndex(GitIndex index, String filePath) async {
    filePath = normalizePath(filePath);

    var file = fs.file(filePath);
    if (!file.existsSync()) {
      return null;
    }

    // Save that file as a blob
    var data = await file.readAsBytes();
    var blob = GitBlob(data, null);
    var hash = await objStorage.writeObject(blob);

    var pathSpec = filePath;
    if (pathSpec.startsWith(workTree)) {
      pathSpec = filePath.substring(workTree.length);
    }

    // Add it to the index
    var entry = index.entries.firstWhereOrNull((e) => e.path == pathSpec);
    var stat = await FileStat.stat(filePath);

    // Existing file
    if (entry != null) {
      entry.hash = hash;
      entry.fileSize = data.length;
      assert(data.length == stat.size);

      entry.cTime = stat.changed;
      entry.mTime = stat.modified;
      return entry;
    }

    // New file
    entry = GitIndexEntry.fromFS(pathSpec, stat, hash);
    index.entries.add(entry);
    return entry;
  }

  Future<void> addDirectoryToIndex(GitIndex index, String dirPath,
      {bool recursive = false}) async {
    dirPath = normalizePath(dirPath);

    var dir = fs.directory(dirPath);
    await for (var fsEntity
        in dir.list(recursive: recursive, followLinks: false)) {
      if (fsEntity.path.startsWith(gitDir)) {
        continue;
      }
      var stat = await fsEntity.stat();
      if (stat.type != FileSystemEntityType.file) {
        continue;
      }

      await addFileToIndex(index, fsEntity.path);
    }
  }

  Future<void> rm(String pathSpec, {bool rmFromFs = true}) async {
    pathSpec = normalizePath(pathSpec);

    var index = await indexStorage.readIndex().get();

    var stat = await fs.stat(pathSpec);
    if (stat.type == FileSystemEntityType.file) {
      await rmFileFromIndex(index, pathSpec);
      if (rmFromFs) {
        await fs.file(pathSpec).delete();
      }
    } else if (stat.type == FileSystemEntityType.directory) {
      await rmDirectoryFromIndex(index, pathSpec, recursive: true);
      if (rmFromFs) {
        await fs.directory(pathSpec).delete(recursive: true);
      }
    } else {
      throw Exception('Neither file or directory');
    }

    await indexStorage.writeIndex(index);
  }

  Future<GitHash?> rmFileFromIndex(GitIndex index, String filePath) async {
    var pathSpec = toPathSpec(normalizePath(filePath));
    return index.removePath(pathSpec);
  }

  Future<void> rmDirectoryFromIndex(GitIndex index, String dirPath,
      {bool recursive = false}) async {
    dirPath = normalizePath(dirPath);

    var dir = fs.directory(dirPath);
    await for (var fsEntity
        in dir.list(recursive: recursive, followLinks: false)) {
      if (fsEntity.path.startsWith(gitDir)) {
        continue;
      }
      var stat = await fsEntity.stat();
      if (stat.type != FileSystemEntityType.file) {
        continue;
      }

      await rmFileFromIndex(index, fsEntity.path);
    }
  }

  Future<GitHash?> deleteBranch(String branchName) async {
    var refName = ReferenceName.branch(branchName);
    var refResult = await refStorage.reference(refName);
    if (refResult.failed) {
      return null;
    }

    await refStorage.deleteReference(refName);
    return refResult.get().hash;
  }

  String normalizePath(String path) {
    if (!path.startsWith('/')) {
      path = path == '.' ? workTree : p.normalize(p.join(workTree, path));
    }
    if (!path.startsWith(workTree)) {
      throw PathSpecOutsideRepoException(pathSpec: path);
    }
    return path;
  }

  String toPathSpec(String path) {
    if (path.startsWith(workTree)) {
      return path.substring(workTree.length);
    }
    if (path.startsWith('/')) {
      throw PathSpecOutsideRepoException(pathSpec: path);
    }

    return path;
  }
}
