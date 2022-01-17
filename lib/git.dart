import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/config.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/storage/config_storage_exception_catcher.dart';
import 'package:dart_git/storage/config_storage_fs.dart';
import 'package:dart_git/storage/index_storage_exception_catcher.dart';
import 'package:dart_git/storage/index_storage_fs.dart';
import 'package:dart_git/storage/interfaces.dart';
import 'package:dart_git/storage/object_storage_exception_catcher.dart';
import 'package:dart_git/storage/object_storage_fs.dart';
import 'package:dart_git/storage/reference_storage_exception_catcher.dart';
import 'package:dart_git/storage/reference_storage_fs.dart';
import 'package:dart_git/utils/git_hash_set.dart';
import 'package:dart_git/utils/local_fs_with_checks.dart';
import 'package:dart_git/utils/result.dart';

export 'commit.dart';
export 'checkout.dart';
export 'merge_base.dart';
export 'merge.dart';
export 'remotes.dart';
export 'utils/result.dart';
export 'index.dart';
export 'vistors.dart';
export 'reset.dart';

export 'storage/object_storage_extensions.dart';

// A Git Repo has 5 parts -
// * Object Store
// * Ref Store
// * Index
// * Working Tree
// * Config
class GitRepository {
  /// Always ends with a '/'
  late String workTree;

  /// The .git directory path.
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

  static Result<GitRepository> load(
    String gitRootDir, {
    FileSystem? fs,
  }) {
    fs ??= const LocalFileSystemWithChecks();

    if (!isValidRepo(gitRootDir, fs: fs)) {
      var ex = InvalidRepoException(gitRootDir);
      return Result.fail(ex);
    }

    var repo = GitRepository._internal(rootDir: gitRootDir, fs: fs);

    repo.objStorage = ObjectStorageExceptionCatcher(
      storage: ObjectStorageFS(repo.gitDir, fs),
    );
    repo.refStorage = ReferenceStorageExceptionCatcher(
      storage: ReferenceStorageFS(repo.gitDir, fs),
    );
    repo.indexStorage = IndexStorageExceptionCatcher(
      storage: IndexStorageFS(repo.gitDir, fs),
    );
    repo.configStorage = ConfigStorageExceptionCatcher(
      storage: ConfigStorageFS(repo.gitDir, fs),
    );

    var configResult = repo.reloadConfig();
    if (configResult.isFailure) {
      return fail(configResult);
    }

    return Result(repo);
  }

  static bool isValidRepo(String gitRootDir, {FileSystem? fs}) {
    fs ??= const LocalFileSystemWithChecks();

    var isDir = fs.isDirectorySync(gitRootDir);
    if (!isDir) {
      return false;
    }

    var repo = GitRepository._internal(rootDir: gitRootDir, fs: fs);
    var dotGitExists = fs.isDirectorySync(repo.gitDir);
    if (!dotGitExists) {
      return false;
    }

    repo.configStorage = ConfigStorageFS(repo.gitDir, fs);
    var configExists = repo.configStorage.exists().getOrThrow();
    if (!configExists) {
      return false;
    }

    return true;
  }

  static Result<void> init(
    String path, {
    FileSystem? fs,
    String defaultBranch = 'master',
    bool ignoreIfExists = false,
  }) {
    return catchAllSync(() => Result(GitRepository._init(
          path,
          fs: fs,
          defaultBranch: defaultBranch,
          ignoreIfExists: ignoreIfExists,
        )));
  }

  static void _init(
    String path, {
    required FileSystem? fs,
    required String defaultBranch,
    required bool ignoreIfExists,
  }) {
    fs ??= const LocalFileSystem();

    var gitDir = p.join(path, '.git');
    if (!ignoreIfExists && fs.directory(gitDir).existsSync()) {
      throw GitRepoExists();
    }

    var dirsToCreate = [
      'branches',
      'objects/pack',
      'refs/heads',
      'refs/tags',
    ];
    for (var dir in dirsToCreate) {
      var _ = fs.directory(p.join(gitDir, dir)).createSync(recursive: true);
    }

    fs.file(p.join(gitDir, 'description')).writeAsStringSync(
        "Unnamed repository; edit this file 'description' to name the repository.\n");
    fs
        .file(p.join(gitDir, refHead))
        .writeAsStringSync('ref: refs/heads/$defaultBranch\n');

    var config = Config('');
    var core = config.getOrCreateSection('core');
    core.options['repositoryformatversion'] = '0';
    core.options['filemode'] = 'false';
    core.options['bare'] = 'false';

    fs.file(p.join(gitDir, 'config')).writeAsStringSync(config.serialize());
  }

  Result<void> reloadConfig() {
    var configResult = configStorage.readConfig();
    if (configResult.isFailure) {
      return fail(configResult);
    }
    config = configResult.getOrThrow();

    return Result(null);
  }

  Result<void> saveConfig() {
    return configStorage.writeConfig(config);
  }

  Result<List<String>> branches() {
    var refsResult = refStorage.listReferences(refHeadPrefix);
    if (refsResult.isFailure) {
      return fail(refsResult);
    }

    var refs = refsResult.getOrThrow();
    var refNames = refs.map((r) => r.name);
    var branchNames = refNames.map((r) => r.branchName()!).toList();

    return Result(branchNames);
  }

  Result<String> currentBranch() {
    var headResult = head();
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

  Result<BranchConfig> setUpstreamTo(
    GitRemoteConfig remote,
    String remoteBranchName,
  ) {
    var branchNameResult = currentBranch();
    if (branchNameResult.isFailure) {
      return fail(branchNameResult);
    }

    var branchName = branchNameResult.getOrThrow();
    return setBranchUpstreamTo(branchName, remote, remoteBranchName);
  }

  Result<BranchConfig> setBranchUpstreamTo(
      String branchName, GitRemoteConfig remote, String remoteBranchName) {
    var brConfig = config.branch(branchName);
    if (brConfig == null) {
      brConfig = BranchConfig(name: branchName);
      config.branches[branchName] = brConfig;
    }
    brConfig.remote = remote.name;
    brConfig.merge = ReferenceName.branch(remoteBranchName);

    var saveR = saveConfig();
    if (saveR.isFailure) {
      return fail(saveR);
    }
    return Result(brConfig);
  }

  Result<GitHash> createBranch(
    String name, {
    GitHash? hash,
    bool overwrite = false,
  }) {
    if (hash == null) {
      var headHashResult = headHash();
      if (headHashResult.isFailure) {
        return fail(headHashResult);
      }
      hash = headHashResult.getOrThrow();
    }

    var branch = ReferenceName.branch(name);
    var refResult = refStorage.reference(branch);
    if (refResult.isFailure && refResult.error is! GitRefNotFound) {
      return fail(refResult);
    }
    if (!overwrite && refResult.isSuccess) {
      var ex = GitBranchAlreadyExists(name);
      return Result.fail(ex);
    }

    var result = refStorage.saveRef(Reference.hash(branch, hash));
    if (result.isFailure) {
      return fail(result);
    }
    return Result(hash);
  }

  Result<GitHash> deleteBranch(String branchName) {
    var refName = ReferenceName.branch(branchName);
    var refResult = refStorage.reference(refName);
    if (refResult.isFailure) {
      return fail(refResult);
    }
    var ref = refResult.getOrThrow();

    var res = refStorage.deleteReference(refName);
    if (res.isFailure) {
      return fail(res);
    }

    return Result(ref.hash!);
  }

  Result<GitCommit> branchCommit(String branchName) {
    var refName = ReferenceName.branch(branchName);
    var refResult = refStorage.reference(refName);
    if (refResult.isFailure) {
      return fail(refResult);
    }
    var ref = refResult.getOrThrow();

    var objR = objStorage.readCommit(ref.hash!);
    if (objR.isFailure) {
      return fail(objR);
    }

    return Result(objR.getOrThrow());
  }

  Result<Reference> head() {
    var result = refStorage.reference(ReferenceName.HEAD());
    if (result.isFailure) {
      return fail(result);
    }

    return Result(result.getOrThrow());
  }

  Result<GitHash> headHash() {
    var result = refStorage.reference(ReferenceName.HEAD());
    if (result.isFailure) {
      return fail(result);
    }

    var ref = result.getOrThrow();
    result = resolveReference(ref);
    if (result.isFailure) {
      return fail(result);
    }

    ref = result.getOrThrow();
    return Result(ref.hash!);
  }

  Result<GitCommit> headCommit() {
    var hashResult = headHash();
    if (hashResult.isFailure) {
      return fail(hashResult);
    }
    var hash = hashResult.getOrThrow();

    var result = objStorage.readCommit(hash);
    if (result.isFailure) {
      return fail(result);
    }
    return Result(result.getOrThrow());
  }

  Result<GitTree> headTree() {
    var commitResult = headCommit();
    if (commitResult.isFailure) {
      return fail(commitResult);
    }
    var commit = commitResult.getOrThrow();

    var res = objStorage.readTree(commit.treeHash);
    if (res.isFailure) {
      return fail(res);
    }
    return Result(res.getOrThrow());
  }

  Result<Reference> resolveReference(Reference ref, {bool recursive = true}) {
    if (ref.type == ReferenceType.Hash) {
      return Result(ref);
    }

    var resolvedRefResult = refStorage.reference(ref.target!);
    if (resolvedRefResult.isFailure) {
      return fail(resolvedRefResult);
    }

    var resolvedRef = resolvedRefResult.getOrThrow();
    return recursive ? resolveReference(resolvedRef) : Result(resolvedRef);
  }

  Result<Reference> resolveReferenceName(ReferenceName refName) {
    var resolvedRefResult = refStorage.reference(refName);
    if (resolvedRefResult.isFailure) {
      return fail(resolvedRefResult);
    }

    var resolvedRef = resolvedRefResult.getOrThrow();
    return resolveReference(resolvedRef);
  }

  Result<bool> canPush() {
    if (config.remotes.isEmpty) {
      return Result(false);
    }

    var headResult = head();
    if (headResult.isFailure) {
      if (headResult.error is! GitRefNotFound) {
        return fail(headResult);
      }
      return Result(false);
    }

    var _head = headResult.getOrThrow();
    if (_head.isHash) {
      return Result(false);
    }

    var brConfig = config.branch(_head.target!.branchName()!);
    var brConfigMerge = brConfig?.merge;
    var brConfigRemote = brConfig?.remote;
    if (brConfig == null || brConfigMerge == null || brConfigRemote == null) {
      // FIXME: Maybe we can push other branches!
      return Result(false);
    }

    var resolvedHeadResult = resolveReference(_head);
    if (resolvedHeadResult.isFailure) {
      return fail(resolvedHeadResult);
    }
    var resolvedHead = resolvedHeadResult.getOrThrow();

    // Construct remote's branch
    var remoteBranchName = brConfigMerge.branchName()!;
    var remoteRefName = ReferenceName.remote(brConfigRemote, remoteBranchName);
    var remoteRefResult = resolveReferenceName(remoteRefName);
    if (remoteRefResult.isFailure) {
      return fail(remoteRefResult);
    }
    var remoteRef = remoteRefResult.getOrThrow();

    return Result(resolvedHead.hash != remoteRef.hash);
  }

  /// Returns -1 if unreachable
  Result<int> countTillAncestor(GitHash from, GitHash ancestor) {
    var seen = GitHashSet();
    var parents = <GitHash>[];
    var _ = parents.add(from);
    while (parents.isNotEmpty) {
      var sha = parents[0];
      if (sha == ancestor) {
        break;
      }
      var _ = parents.removeAt(0);
      var __ = seen.add(sha);

      var commitR = objStorage.readCommit(sha);
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

  Result<int> numChangesToPush() {
    var headR = this.head();
    if (headR.isFailure) {
      return fail(headR);
    }
    var head = headR.getOrThrow();
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

    var headRefResult = resolveReference(head);
    var remoteRefResult = resolveReferenceName(remoteRefName);
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

    var aheadByResult = countTillAncestor(headHash, remoteHash);
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
