import 'dart:async';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/config.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/git_hash.dart';
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
import 'package:dart_git/utils/local_fs_with_checks.dart';
import 'package:dart_git/utils/result.dart';

export 'commit.dart';
export 'checkout.dart';
export 'merge_base.dart';
export 'remotes.dart';
export 'utils/result.dart';
export 'index.dart';

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
    if (configResult.isFailure) {
      return fail(configResult);
    }
    repo.config = configResult.getOrThrow();

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
    var configExists = await repo.configStorage.exists().getOrThrow();
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
    if (refsResult.isFailure) {
      return fail(refsResult);
    }

    var refs = refsResult.getOrThrow();
    var refNames = refs.map((r) => r.name);
    var branchNames = refNames.map((r) => r.branchName()!).toList();

    return Result(branchNames);
  }

  Future<Result<String>> currentBranch() async {
    var headResult = await head();
    if (headResult.isFailure) {
      return fail(headResult);
    }

    var _head = headResult.getOrThrow();
    if (_head.isHash) {
      var ex = GitHeadDetached();
      return Result.fail(ex);
    }

    // FIXE: Am I sure this will never throw an error?
    var name = _head.target!.branchName()!;
    return Result(name);
  }

  Future<Result<BranchConfig>> setUpstreamTo(
    GitRemoteConfig remote,
    String remoteBranchName,
  ) async {
    var branchNameResult = await currentBranch();
    if (branchNameResult.isFailure) {
      return fail(branchNameResult);
    }

    var branchName = branchNameResult.getOrThrow();
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
    if (saveR.isFailure) {
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
      if (headHashResult.isFailure) {
        return fail(headHashResult);
      }
      hash = headHashResult.getOrThrow();
    }

    var branch = ReferenceName.branch(name);
    var refResult = await refStorage.reference(branch);
    if (refResult.isFailure && refResult.error is! GitRefNotFound) {
      return fail(refResult);
    }
    if (!overwrite && refResult.isSuccess) {
      var ex = GitBranchAlreadyExists(name);
      return Result.fail(ex);
    }

    var result = await refStorage.saveRef(Reference.hash(branch, hash));
    if (result.isFailure) {
      return fail(result);
    }
    return Result(hash);
  }

  Future<Result<GitHash>> deleteBranch(String branchName) async {
    var refName = ReferenceName.branch(branchName);
    var refResult = await refStorage.reference(refName);
    if (refResult.isFailure) {
      return fail(refResult);
    }
    var ref = refResult.getOrThrow();

    var res = await refStorage.deleteReference(refName);
    if (res.isFailure) {
      return fail(res);
    }

    return Result(ref.hash!);
  }

  Future<Result<Reference>> head() async {
    var result = await refStorage.reference(ReferenceName('HEAD'));
    if (result.isFailure) {
      return fail(result);
    }

    return Result(result.getOrThrow());
  }

  Future<Result<GitHash>> headHash() async {
    var result = await refStorage.reference(ReferenceName('HEAD'));
    if (result.isFailure) {
      return fail(result);
    }

    var ref = result.getOrThrow();
    result = await resolveReference(ref);
    if (result.isFailure) {
      return fail(result);
    }

    ref = result.getOrThrow();
    return Result(ref.hash!);
  }

  Future<Result<GitCommit>> headCommit() async {
    var hashResult = await headHash();
    if (hashResult.isFailure) {
      return fail(hashResult);
    }
    var hash = hashResult.getOrThrow();

    var result = await objStorage.readCommit(hash);
    if (result.isFailure) {
      return fail(result);
    }
    return Result(result.getOrThrow());
  }

  Future<Result<GitTree>> headTree() async {
    var commitResult = await headCommit();
    if (commitResult.isFailure) {
      return fail(commitResult);
    }
    var commit = commitResult.getOrThrow();

    var res = await objStorage.readTree(commit.treeHash);
    if (res.isFailure) {
      return fail(res);
    }
    return Result(res.getOrThrow());
  }

  Future<Result<Reference>> resolveReference(
    Reference ref, {
    bool recursive = true,
  }) async {
    if (ref.type == ReferenceType.Hash) {
      return Result(ref);
    }

    var resolvedRefResult = await refStorage.reference(ref.target!);
    if (resolvedRefResult.isFailure) {
      return fail(resolvedRefResult);
    }

    var resolvedRef = resolvedRefResult.getOrThrow();
    return recursive
        ? await resolveReference(resolvedRef)
        : Result(resolvedRef);
  }

  Future<Result<Reference>> resolveReferenceName(ReferenceName refName) async {
    var resolvedRefResult = await refStorage.reference(refName);
    if (resolvedRefResult.isFailure) {
      return fail(resolvedRefResult);
    }

    var resolvedRef = resolvedRefResult.getOrThrow();
    return resolveReference(resolvedRef);
  }

  Future<bool> canPush() async {
    if (config.remotes.isEmpty) {
      return false;
    }

    var headResult = await head();
    if (headResult.isFailure) {
      return false;
    }

    var _head = headResult.getOrThrow();
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
    if (resolvedHeadResult.isFailure) {
      return false;
    }
    var resolvedHead = resolvedHeadResult.getOrThrow();

    // Construct remote's branch
    var remoteBranchName = brConfigMerge.branchName()!;
    var remoteRefName = ReferenceName.remote(brConfigRemote, remoteBranchName);
    var remoteRefResult = await resolveReferenceName(remoteRefName);
    if (remoteRefResult.isFailure) {
      return false;
    }
    var remoteRef = remoteRefResult.getOrThrow();

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
      if (commitR.isFailure) {
        return fail(commitR);
      }
      var commit = commitR.getOrThrow();

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
    if (headRefResult.isFailure) {
      return fail(headRefResult);
    }
    if (remoteRefResult.isFailure) {
      return fail(remoteRefResult);
    }

    var headHash = headRefResult.getOrThrow().hash!;
    var remoteHash = remoteRefResult.getOrThrow().hash!;

    if (headHash == remoteHash) {
      return Result(0);
    }

    var aheadByResult = await countTillAncestor(headHash, remoteHash);
    if (aheadByResult.isFailure) {
      return fail(aheadByResult);
    }
    var aheadBy = aheadByResult.getOrThrow();

    return Result(aheadBy != -1 ? aheadBy : 0);
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
