import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/config.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/storage/config_storage_fs.dart';
import 'package:dart_git/storage/index_storage_fs.dart';
import 'package:dart_git/storage/interfaces.dart';
import 'package:dart_git/storage/object_storage_fs.dart';
import 'package:dart_git/storage/reference_storage_fs.dart';
import 'package:dart_git/utils/git_hash_set.dart';
import 'package:dart_git/utils/local_fs_with_checks.dart';

export 'commit.dart';
export 'checkout.dart';
export 'merge_base.dart';
export 'merge.dart';
export 'remotes.dart';
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

  /// The .git directory path. Always ends with '/'
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
    if (!gitDir.endsWith(p.separator)) {
      gitDir += p.separator;
    }
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

  static GitRepository load(
    String gitRootDir, {
    FileSystem? fs,
  }) {
    fs ??= const LocalFileSystemWithChecks();

    if (!isValidRepo(gitRootDir, fs: fs)) {
      var ex = InvalidRepoException(gitRootDir);
      return throw ex;
    }

    var repo = GitRepository._internal(rootDir: gitRootDir, fs: fs);

    repo.objStorage = ObjectStorageFS(repo.gitDir, fs);
    repo.refStorage = ReferenceStorageFS(repo.gitDir, fs);
    repo.indexStorage = IndexStorageFS(repo.gitDir, fs);
    repo.configStorage = ConfigStorageFS(repo.gitDir, fs);

    repo.reloadConfig();
    return repo;
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
    var configExists = repo.configStorage.exists();
    if (!configExists) {
      return false;
    }

    return true;
  }

  static void init(
    String path, {
    FileSystem? fs,
    String defaultBranch = 'main',
    bool ignoreIfExists = false,
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
      fs.directory(p.join(gitDir, dir)).createSync(recursive: true);
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

  void close() {
    objStorage.close();
    refStorage.close();
    indexStorage.close();
  }

  void reloadConfig() {
    config = configStorage.readConfig();
  }

  void saveConfig() {
    return configStorage.writeConfig(config);
  }

  List<String> branches() {
    var refs = refStorage.listReferences(refHeadPrefix);
    var refNames = refs.map((r) => r.name);
    var branchNames = refNames.map((r) => r.branchName()!).toList();

    return branchNames;
  }

  String currentBranch() {
    var _head = head();
    if (_head.isHash) {
      var ex = GitHeadDetached();
      return throw ex;
    }

    var name = _head.target!.branchName()!;
    return name;
  }

  BranchConfig setUpstreamTo(
    GitRemoteConfig remote,
    String remoteBranchName,
  ) {
    var branchName = currentBranch();
    return setBranchUpstreamTo(branchName, remote, remoteBranchName);
  }

  BranchConfig setBranchUpstreamTo(
      String branchName, GitRemoteConfig remote, String remoteBranchName) {
    var brConfig = config.branch(branchName);
    if (brConfig == null) {
      brConfig = BranchConfig(name: branchName);
      config.branches[branchName] = brConfig;
    }
    brConfig.remote = remote.name;
    brConfig.merge = ReferenceName.branch(remoteBranchName);

    saveConfig();
    return brConfig;
  }

  GitHash createBranch(
    String name, {
    GitHash? hash,
    bool overwrite = false,
  }) {
    hash ??= headHash();

    var branch = ReferenceName.branch(name);
    try {
      // Try to read the reference
      refStorage.reference(branch);

      if (!overwrite) {
        throw GitBranchAlreadyExists(name);
      }
    } on GitRefNotFound {
      // That's fine
    }

    refStorage.saveRef(Reference.hash(branch, hash));
    return hash;
  }

  GitHash deleteBranch(String branchName) {
    var refName = ReferenceName.branch(branchName);
    var ref = refStorage.reference(refName);
    refStorage.deleteReference(refName);

    return ref.hash!;
  }

  GitCommit branchCommit(String branchName) {
    var refName = ReferenceName.branch(branchName);
    var ref = refStorage.reference(refName);

    return objStorage.readCommit(ref.hash!);
  }

  Reference head() {
    return refStorage.reference(ReferenceName.HEAD());
  }

  GitHash headHash() {
    var ref = refStorage.reference(ReferenceName.HEAD());

    ref = resolveReference(ref);
    return ref.hash!;
  }

  GitCommit headCommit() {
    var hash = headHash();
    return objStorage.readCommit(hash);
  }

  GitTree headTree() {
    var commit = headCommit();
    return objStorage.readTree(commit.treeHash);
  }

  Reference resolveReference(Reference ref, {bool recursive = true}) {
    if (ref.type == ReferenceType.Hash) {
      return ref;
    }

    var resolvedRef = refStorage.reference(ref.target!);
    return recursive ? resolveReference(resolvedRef) : resolvedRef;
  }

  Reference resolveReferenceName(ReferenceName refName) {
    var resolvedRef = refStorage.reference(refName);
    return resolveReference(resolvedRef);
  }

  bool canPush() {
    if (config.remotes.isEmpty) {
      return false;
    }

    late Reference _head;
    try {
      _head = head();
    } on GitRefNotFound {
      return false;
    }
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

    var resolvedHead = resolveReference(_head);

    // Construct remote's branch
    var remoteBranchName = brConfigMerge.branchName()!;
    var remoteRefName = ReferenceName.remote(brConfigRemote, remoteBranchName);
    var remoteRef = resolveReferenceName(remoteRefName);

    return resolvedHead.hash != remoteRef.hash;
  }

  /// Returns -1 if unreachable
  int countTillAncestor(GitHash from, GitHash ancestor) {
    var seen = GitHashSet();
    var parents = <GitHash>[];
    parents.add(from);
    while (parents.isNotEmpty) {
      var sha = parents[0];
      if (sha == ancestor) {
        break;
      }
      parents.removeAt(0);
      seen.add(sha);

      var commit = objStorage.readCommit(sha);
      for (var p in commit.parents) {
        if (seen.contains(p)) continue;
        parents.add(p);
      }
    }

    return parents.isEmpty ? -1 : seen.length;
  }

  int numChangesToPush() {
    var head = this.head();
    if (head.isHash || head.target == null) {
      return 0;
    }

    var brConfig = config.branch(head.target!.branchName()!);
    var brConfigMerge = brConfig?.merge;
    var brConfigRemote = brConfig?.remote;
    if (brConfig == null || brConfigMerge == null || brConfigRemote == null) {
      return 0;
    }

    // Construct remote's branch
    var remoteBranchName = brConfigMerge.branchName()!;
    var remoteRefName = ReferenceName.remote(brConfigRemote, remoteBranchName);

    var headRef = resolveReference(head);
    var remoteRef = resolveReferenceName(remoteRefName);

    var headHash = headRef.hash!;
    var remoteHash = remoteRef.hash!;

    if (headHash == remoteHash) {
      return 0;
    }

    var aheadBy = countTillAncestor(headHash, remoteHash);
    return aheadBy != -1 ? aheadBy : 0;
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
