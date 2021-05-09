import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/config.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/fs.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/storage/index_storage.dart';
import 'package:dart_git/storage/object_storage.dart';
import 'package:dart_git/storage/object_storage_exception_catcher.dart';
import 'package:dart_git/storage/reference_storage.dart';

export 'commit.dart';
export 'checkout.dart';
export 'merge_base.dart';

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

  GitRepository._internal({required String rootDir, required this.fs}) {
    workTree = rootDir;
    if (!workTree.endsWith(p.separator)) {
      workTree += p.separator;
    }
    gitDir = p.join(workTree, '.git');
  }

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

  static Future<GitRepository> load(String gitRootDir, {FileSystem? fs}) async {
    fs ??= const LocalFileSystemWithChecks();

    if (!(await isValidRepo(gitRootDir, fs: fs))) {
      throw InvalidRepoException(gitRootDir);
    }

    var repo = GitRepository._internal(rootDir: gitRootDir, fs: fs);

    var configPath = p.join(repo.gitDir, 'config');
    var configFileContents = await fs.file(configPath).readAsString();
    repo.config = Config(configFileContents);

    repo.objStorage = ObjectStorageExceptionCatcher(
      storage: ObjectStorage(repo.gitDir, fs),
    );
    repo.refStorage = ReferenceStorage(repo.gitDir, fs);
    repo.indexStorage = IndexStorage(repo.gitDir, fs);

    return repo;
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

    var configPath = p.join(repo.gitDir, 'config');
    if (!fs.isFileSync(configPath)) {
      return false;
    }

    return true;
  }

  static Future<void> init(String path, {FileSystem? fs}) async {
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
        .writeAsString('ref: refs/heads/master\n');

    var config = Config('');
    var core = config.section('core');
    core.options['repositoryformatversion'] = '0';
    core.options['filemode'] = 'false';
    core.options['bare'] = 'false';

    await fs.file(p.join(gitDir, 'config')).writeAsString(config.serialize());
  }

  Future<void> saveConfig() {
    return fs.file(p.join(gitDir, 'config')).writeAsString(config.serialize());
  }

  Future<List<String>> branches() async {
    var refs = await refStorage.listReferences(refHeadPrefix);
    var refNames = refs.map((r) => r.name);

    return refNames.map((r) => r.branchName()!).toList();
  }

  Future<String?> currentBranch() async {
    var _head = await head();
    if (_head == null || _head.isHash) {
      return null;
    }

    return _head.target!.branchName();
  }

  Future<BranchConfig?> setUpstreamTo(
      GitRemoteConfig remote, String remoteBranchName) async {
    var branchName = await currentBranch();
    if (branchName == null) {
      // FIXME: I don't like this silently returning null
      //        If this is failing, please give me an error!
      return null;
    }
    return setBranchUpstreamTo(branchName, remote, remoteBranchName);
  }

  Future<BranchConfig> setBranchUpstreamTo(String branchName,
      GitRemoteConfig remote, String remoteBranchName) async {
    var brConfig = config.branch(branchName);
    if (brConfig == null) {
      brConfig = BranchConfig(name: branchName);
      config.branches[branchName] = brConfig;
    }
    brConfig.remote = remote.name;
    brConfig.merge = ReferenceName.branch(remoteBranchName);

    await saveConfig();
    return brConfig;
  }

  Future<GitHash?> createBranch(
    String name, {
    GitHash? hash,
    bool overwrite = false,
  }) async {
    hash ??= await headHash();
    if (hash == null) {
      return null;
    }

    var branch = ReferenceName.branch(name);
    var ref = await refStorage.reference(branch);
    if (!overwrite && ref != null) {
      return null;
    }

    await refStorage.saveRef(Reference.hash(branch, hash));
    return hash;
  }

  Future<List<Reference>> remoteBranches(String remoteName) async {
    if (config.remote(remoteName) == null) {
      throw Exception('remote $remoteName does not exist');
    }

    var remoteRefsPrefix = '$refRemotePrefix$remoteName/';
    return refStorage.listReferences(remoteRefsPrefix);
  }

  Future<Reference?> remoteBranch(String remoteName, String branchName) async {
    if (config.remote(remoteName) == null) {
      throw Exception('remote $remoteName does not exist');
    }

    var remoteRef = ReferenceName.remote(remoteName, branchName);
    return refStorage.reference(remoteRef);
  }

  Future<GitRemoteConfig> addRemote(String name, String url) async {
    var existingRemote = config.remotes.firstWhereOrNull(
      (r) => r.name == name,
    );
    if (existingRemote != null) {
      throw Exception('fatal: remote "$name" already exists.');
    }

    var remote = GitRemoteConfig.create(name: name, url: url);
    config.remotes.add(remote);

    await saveConfig();

    return remote;
  }

  Future<GitRemoteConfig> addOrUpdateRemote(String name, String url) async {
    var i = config.remotes.indexWhere((r) => r.name == name);
    if (i == -1) {
      return addRemote(name, url);
    }

    config.remotes[i] = GitRemoteConfig(
      name: config.remotes[i].name,
      fetch: config.remotes[i].fetch,
      url: url,
    );
    await saveConfig();

    return config.remotes[i];
  }

  Future<GitRemoteConfig?> removeRemote(String name) async {
    var i = config.remotes.indexWhere((r) => r.name == name);
    if (i == -1) {
      return null;
    }

    var remote = config.remotes[i];
    config.remotes.removeAt(i);
    await saveConfig();

    await refStorage.removeReferences(refRemotePrefix + name);
    // TODO: Remote the objects from that remote?

    return remote;
  }

  Future<Reference?> head() async {
    return refStorage.reference(ReferenceName('HEAD'));
  }

  Future<GitHash?> headHash() async {
    var ref = await refStorage.reference(ReferenceName('HEAD'));
    if (ref == null) {
      return null;
    }

    ref = await resolveReference(ref);
    if (ref == null) {
      return null;
    }
    return ref.hash;
  }

  Future<GitCommit?> headCommit() async {
    var hash = await headHash();
    if (hash == null) {
      return null;
    }
    var res = await objStorage.readCommit(hash);
    return res.get();
  }

  Future<GitTree?> headTree() async {
    var commit = await headCommit();
    if (commit == null) {
      return null;
    }

    var res = await objStorage.readTree(commit.treeHash);
    return res.get();
  }

  Future<Reference?> resolveReference(Reference ref,
      {bool recursive = true}) async {
    if (ref.type == ReferenceType.Hash) {
      return ref;
    }

    var resolvedRef = await refStorage.reference(ref.target!);
    if (resolvedRef == null) {
      return null;
    }
    return recursive
        ? resolveReference(resolvedRef) as FutureOr<Reference?>
        : resolvedRef;
  }

  Future<Reference?> resolveReferenceName(ReferenceName refName) async {
    var resolvedRef = await refStorage.reference(refName);
    if (resolvedRef == null) {
      print('resolveReferenceName($refName) failed');
      return null;
    }
    return resolveReference(resolvedRef);
  }

  Future<bool> canPush() async {
    if (config.remotes.isEmpty) {
      return false;
    }

    var head = await this.head();
    if (head == null || head.isHash) {
      return false;
    }

    var brConfig = config.branch(head.target!.branchName()!);
    var brConfigMerge = brConfig?.merge;
    var brConfigRemote = brConfig?.remote;
    if (brConfig == null || brConfigMerge == null || brConfigRemote == null) {
      // FIXME: Maybe we can push other branches!
      return false;
    }

    var resolvedHead = await resolveReference(head);
    if (resolvedHead == null) {
      return false;
    }

    // Construct remote's branch
    var remoteBranchName = brConfigMerge.branchName()!;
    var remoteRefName = ReferenceName.remote(brConfigRemote, remoteBranchName);
    var remoteRef = await resolveReferenceName(remoteRefName);
    if (remoteRef == null) {
      return false;
    }

    return resolvedHead.hash != remoteRef.hash;
  }

  Future<int?> countTillAncestor(GitHash from, GitHash ancestor) async {
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

      GitCommit? commit;
      try {
        var res = await objStorage.readCommit(sha);
        commit = res.get();
      } catch (e) {
        print(e);
        return null;
      }

      for (var p in commit.parents) {
        if (seen.contains(p)) continue;
        parents.add(p);
      }
    }

    return parents.isEmpty ? null : seen.length;
  }

  Future<Reference?> guessRemoteHead(String remoteName) async {
    // See: https://stackoverflow.com/questions/8839958/how-does-origin-head-get-set/25430727#25430727
    //      https://stackoverflow.com/questions/8839958/how-does-origin-head-get-set/8841024#8841024
    //
    // The ideal way is to use https://libgit2.org/libgit2/#HEAD/group/remote/git_remote_default_branch
    //
    var branches = await remoteBranches(remoteName);
    if (branches.isEmpty) {
      return null;
    }

    var i = branches.indexWhere((b) => b.name.branchName() == 'HEAD');
    if (i != -1) {
      var remoteHead = branches[i];
      assert(remoteHead.isSymbolic);

      return resolveReference(remoteHead);
    } else {
      branches = branches.where((b) => b.name.branchName() != 'HEAD').toList();
    }

    if (branches.length == 1) {
      return branches[0];
    }

    var mi = branches.indexWhere((e) => e.name.branchName() == 'master');
    if (mi != -1) {
      return branches[mi];
    }

    mi = branches.indexWhere((e) => e.name.branchName() == 'main');
    if (mi != -1) {
      return branches[mi];
    }

    // Return the first alphabetical one
    branches
        .sort((a, b) => a.name.branchName()!.compareTo(b.name.branchName()!));
    return branches[0];
  }

  Future<int?> numChangesToPush() async {
    var head = await (this.head() as FutureOr<Reference>);
    if (head.isHash || head.target == null) {
      return null;
    }

    var brConfig = config.branch(head.target!.branchName()!);
    var brConfigMerge = brConfig?.merge;
    var brConfigRemote = brConfig?.remote;
    if (brConfig == null || brConfigMerge == null || brConfigRemote == null) {
      return null;
    }

    // Construct remote's branch
    var remoteBranchName = brConfigMerge.branchName()!;
    var remoteRefName = ReferenceName.remote(brConfigRemote, remoteBranchName);

    var headRef = await resolveReference(head);
    var remoteRef = await resolveReferenceName(remoteRefName);
    if (headRef == null || remoteRef == null) {
      return null;
    }
    var headHash = headRef.hash;
    var remoteHash = headRef.hash;

    if (headHash == null || remoteHash == null) {
      return null;
    }
    if (headHash == remoteHash) {
      return 0;
    }

    var aheadBy = await countTillAncestor(headHash, remoteHash);
    return aheadBy != -1 ? aheadBy : 0;
  }

  Future<void> add(String pathSpec) async {
    pathSpec = normalizePath(pathSpec);

    var index = await indexStorage.readIndex();

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

    var index = await indexStorage.readIndex();

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
    var ref = await refStorage.reference(refName);
    if (ref == null) {
      return null;
    }

    await refStorage.deleteReference(refName);
    return ref.hash;
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
