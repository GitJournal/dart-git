import 'dart:io';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/config.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/storage/object_storage.dart';
import 'package:dart_git/storage/reference_storage.dart';

class GitRepository {
  String workTree;
  String gitDir;

  Config config;

  FileSystem fs;
  ReferenceStorage refStorage;
  ObjectStorage objStorage;

  GitRepository._internal({@required String rootDir, @required this.fs}) {
    workTree = rootDir;
    if (!workTree.endsWith(p.separator)) {
      workTree += p.separator;
    }
    gitDir = p.join(workTree, '.git');
  }

  static String findRootDir(String path, {FileSystem fs}) {
    fs ??= const LocalFileSystem();

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

  static Future<GitRepository> load(String gitRootDir, {FileSystem fs}) async {
    fs ??= const LocalFileSystem();

    var repo = GitRepository._internal(rootDir: gitRootDir, fs: fs);

    var isDir = await fs.isDirectory(gitRootDir);
    if (!isDir) {
      throw InvalidRepoException(gitRootDir);
    }

    var dotGitExists = await fs.isDirectory(repo.gitDir);
    if (!dotGitExists) {
      throw InvalidRepoException(gitRootDir);
    }

    var configPath = p.join(repo.gitDir, 'config');
    var configFileContents = await fs.file(configPath).readAsString();
    repo.config = Config(configFileContents);

    repo.objStorage = ObjectStorage(repo.gitDir, fs);
    repo.refStorage = ReferenceStorage(repo.gitDir, fs);

    return repo;
  }

  static Future<void> init(String path, {FileSystem fs}) async {
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
    return refNames.map((r) => r.branchName()).toList();
  }

  Future<String> currentBranch() async {
    var _head = await head();
    if (_head.isHash) {
      return null;
    }

    return _head.target.branchName();
  }

  Future<BranchConfig> setUpstreamTo(
      GitRemoteConfig remote, String remoteBranchName) async {
    var branchName = await currentBranch();
    var brConfig = await config.branch(branchName);
    if (brConfig == null) {
      brConfig = BranchConfig();
      brConfig.name = branchName;

      config.branches[branchName] = brConfig;
    }
    brConfig.remote = remote.name;
    brConfig.merge = ReferenceName.head(remoteBranchName);

    await saveConfig();
    return brConfig;
  }

  Future<GitHash> createBranch(String name, [GitHash hash]) async {
    if (hash == null) {
      var headRef = await resolveReference(await head());
      hash = headRef.hash;
    }

    var branch = ReferenceName.head(name);
    var ref = await refStorage.reference(branch);
    if (ref != null) {
      throw BranchAlreadyExistsException(name);
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

  Future<Reference> remoteBranch(String remoteName, String branchName) async {
    if (config.remote(remoteName) == null) {
      throw Exception('remote $remoteName does not exist');
    }

    var remoteRef = ReferenceName.remote(remoteName, branchName);
    return refStorage.reference(remoteRef);
  }

  Future<Reference> guessRemoteHead(String remoteName) async {
    // See: https://stackoverflow.com/questions/8839958/how-does-origin-head-get-set/25430727#25430727
    //      https://stackoverflow.com/questions/8839958/how-does-origin-head-get-set/8841024#8841024
    //
    // The ideal way is to use https://libgit2.org/libgit2/#HEAD/group/remote/git_remote_default_branch
    // This would require a lot of code, though
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

    // Return the first alphabetical one
    branches.sort((a, b) => a.name.branchName().compareTo(b.name.branchName()));
    return branches[0];
  }

  Future<GitRemoteConfig> addRemote(String name, String url) async {
    var existingRemote = config.remotes.firstWhere(
      (r) => r.name == name,
      orElse: () => null,
    );
    if (existingRemote != null) {
      throw Exception('fatal: remote "$name" already exists.');
    }

    var remote = GitRemoteConfig.create(name: name, url: url);
    config.remotes.add(remote);

    await saveConfig();

    return remote;
  }

  Future<GitRemoteConfig> removeRemote(String name) async {
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

  Future<Reference> head() async {
    return refStorage.reference(ReferenceName('HEAD'));
  }

  Future<Reference> resolveReference(
    Reference ref, {
    bool recursive = true,
  }) async {
    if (ref.type == ReferenceType.Hash) {
      return ref;
    }

    var resolvedRef = await refStorage.reference(ref.target);
    if (resolvedRef == null) {
      return null;
    }
    return recursive ? resolveReference(resolvedRef) : resolvedRef;
  }

  Future<Reference> resolveReferenceName(ReferenceName refName) async {
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

    var brConfig = await config.branch(head.target.branchName());
    if (brConfig == null) {
      // FIXME: Maybe we can push other branches!
      return false;
    }

    var resolvedHead = await resolveReference(head);
    if (resolvedHead == null) {
      return false;
    }

    // Construct remote's branch
    var remoteBranchName = brConfig.merge.branchName();
    var remoteRef = ReferenceName.remote(brConfig.remote, remoteBranchName);

    var headHash = resolvedHead.hash;
    var remoteHash = (await resolveReferenceName(remoteRef)).hash;
    return headHash != remoteHash;
  }

  Future<int> countTillAncestor(GitHash from, GitHash ancestor) async {
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

      GitObject obj;
      try {
        obj = await objStorage.readObjectFromHash(sha);
      } catch (e) {
        print(e);
        return -1;
      }
      assert(obj is GitCommit);
      var commit = obj as GitCommit;

      for (var p in commit.parents) {
        if (seen.contains(p)) continue;
        parents.add(p);
      }
    }

    return parents.isEmpty ? -1 : seen.length;
  }

  Future<GitIndex> readIndex() async {
    var file = fs.file(p.join(gitDir, 'index'));
    if (!file.existsSync()) {
      return GitIndex(versionNo: 2);
    }

    return GitIndex.decode(await file.readAsBytes());
  }

  Future<void> writeIndex(GitIndex index) async {
    var path = p.join(gitDir, 'index.new');
    var file = fs.file(path);
    await file.writeAsBytes(index.serialize());
    await file.rename(p.join(gitDir, 'index'));
  }

  Future<int> numChangesToPush() async {
    var head = await this.head();
    if (head.isHash) {
      return 0;
    }

    var brConfig = await config.branch(head.target.branchName());
    if (brConfig == null) {
      return 0;
    }

    // Construct remote's branch
    var remoteBranchName = brConfig.merge.branchName();
    var remoteRef = ReferenceName.remote(brConfig.remote, remoteBranchName);

    var headHash = (await resolveReference(head)).hash;
    var remoteHash = (await resolveReferenceName(remoteRef)).hash;

    if (headHash == null || remoteHash == null) {
      return 0;
    }
    if (headHash == remoteHash) {
      return 0;
    }

    var aheadBy = await countTillAncestor(headHash, remoteHash);
    return aheadBy != -1 ? aheadBy : 0;
  }

  Future<void> addFileToIndex(GitIndex index, String filePath) async {
    filePath = _normalizePath(filePath);

    var file = fs.file(filePath);
    if (!file.existsSync()) {
      throw Exception("fatal: pathspec '$filePath' did not match any files");
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
    GitIndexEntry entry;
    for (var e in index.entries) {
      if (e.path == pathSpec) {
        entry = e;
        break;
      }
    }

    var stat = await FileStat.stat(filePath);

    // Existing file
    if (entry != null) {
      entry.hash = hash;
      entry.fileSize = data.length;

      entry.cTime = stat.changed;
      entry.mTime = stat.modified;
      return;
    }

    // New file
    entry = GitIndexEntry.fromFS(pathSpec, stat, hash);
    index.entries.add(entry);
  }

  Future<void> addDirectoryToIndex(GitIndex index, String dirPath,
      {bool recursive = false}) async {
    dirPath = _normalizePath(dirPath);

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

      print(fsEntity.path);
      await addFileToIndex(index, fsEntity.path);
    }
  }

  Future<GitHash> rmFileFromIndex(GitIndex index, String filePath) async {
    var pathSpec = toPathSpec(_normalizePath(filePath));

    var i = index.entries.indexWhere((e) => e.path == pathSpec);
    if (i == -1) {
      throw PathSpecInvalidException(pathSpec: filePath);
    }

    var indexEntry = index.entries.removeAt(i);
    return indexEntry.hash;
  }

  Future<GitCommit> commit({
    @required String message,
    @required GitAuthor author,
    GitAuthor committer,
    bool addAll = false,
  }) async {
    committer ??= author;

    var index = await readIndex();

    if (addAll) {
      await addDirectoryToIndex(index, workTree, recursive: true);
      await writeIndex(index);
    }

    var treeHash = await writeTree(index);
    var parents = <GitHash>[];

    var headRef = await head();
    if (headRef != null) {
      var parentRef = await resolveReference(headRef);
      if (parentRef != null) {
        parents.add(parentRef.hash);
      }
    }

    var commit = GitCommit.create(
      author: author,
      committer: committer,
      parents: parents,
      message: message,
      treeHash: treeHash,
    );
    var hash = await objStorage.writeObject(commit);

    // Update the ref of the current branch
    var branchName = await currentBranch();
    if (branchName == null) {
      var h = await head();
      assert(h.target.isBranch());
      branchName = h.target.branchName();
    }

    var newRef = Reference.hash(ReferenceName.head(branchName), hash);

    await refStorage.saveRef(newRef);

    return commit;
  }

  Future<GitHash> writeTree(GitIndex index) async {
    var allTreeDirs = {''};
    var treeObjects = {'': GitTree.empty()};
    var treeObjFullPath = <GitTree, String>{};

    index.entries.forEach((entry) {
      var fullPath = entry.path;
      var fileName = p.basename(fullPath);
      var dirName = p.dirname(fullPath);

      // Construct all the tree objects
      var allDirs = <String>[];
      while (dirName != '.') {
        allTreeDirs.add(dirName);
        allDirs.add(dirName);

        dirName = p.dirname(dirName);
      }

      allDirs.sort(dirSortFunc);

      for (var dir in allDirs) {
        if (!treeObjects.containsKey(dir)) {
          var tree = GitTree.empty();
          treeObjects[dir] = tree;
        }

        var parentDir = p.dirname(dir);
        if (parentDir == '.') parentDir = '';

        var parentTree = treeObjects[parentDir];
        var folderName = p.basename(dir);
        treeObjFullPath[parentTree] = parentDir;

        var i = parentTree.leaves.indexWhere((e) => e.path == folderName);
        if (i != -1) {
          continue;
        }
        parentTree.leaves.add(GitTreeLeaf(
          mode: GitFileMode.Dir,
          path: folderName,
          hash: null,
        ));
      }

      dirName = p.dirname(fullPath);
      if (dirName == '.') {
        dirName = '';
      }

      var leaf = GitTreeLeaf(
        mode: entry.mode,
        path: fileName,
        hash: entry.hash,
      );
      treeObjects[dirName].leaves.add(leaf);
    });
    assert(treeObjects.containsKey(''));

    // Write all the tree objects
    var hashMap = <String, GitHash>{};

    var allDirs = allTreeDirs.toList();
    allDirs.sort(dirSortFunc);

    for (var dir in allDirs.reversed) {
      var tree = treeObjects[dir];
      assert(tree != null);

      for (var i = 0; i < tree.leaves.length; i++) {
        var leaf = tree.leaves[i];

        if (leaf.hash != null) {
          assert(await () async {
            var leafObj = await objStorage.readObjectFromHash(leaf.hash);
            return leafObj.formatStr() == 'blob';
          }());
          continue;
        }

        var fullPath = p.join(treeObjFullPath[tree], leaf.path);
        var hash = hashMap[fullPath];
        assert(hash != null);

        tree.leaves[i] = GitTreeLeaf(
          mode: leaf.mode,
          path: leaf.path,
          hash: hash,
        );
      }

      for (var leaf in tree.leaves) {
        assert(leaf.hash != null);
      }

      var hash = await objStorage.writeObject(tree);
      hashMap[dir] = hash;
    }

    return hashMap[''];
  }

  Future<int> checkout(String path) async {
    path = _normalizePath(path);

    var headRef = await resolveReference(await head());

    var obj = await objStorage.readObjectFromHash(headRef.hash);
    var commit = obj as GitCommit;

    obj = await objStorage.readObjectFromHash(commit.treeHash);
    var tree = obj as GitTree;

    var spec = path.substring(workTree.length);
    obj = await objStorage.refSpec(tree, spec);
    if (obj == null) {
      return null;
    }

    if (obj is GitBlob) {
      await fs.directory(p.dirname(path)).create(recursive: true);
      await fs.file(path).writeAsBytes(obj.blobData);
      return 1;
    }

    var index = GitIndex(versionNo: 2);
    var numFiles = await _checkoutTree(spec, obj as GitTree, index);
    await writeIndex(index);

    return numFiles;
  }

  Future<int> _checkoutTree(
      String relativePath, GitTree tree, GitIndex index) async {
    assert(!relativePath.startsWith(p.separator));

    var updated = 0;
    for (var leaf in tree.leaves) {
      var obj = await objStorage.readObjectFromHash(leaf.hash);
      assert(obj != null);

      var leafRelativePath = p.join(relativePath, leaf.path);
      if (obj is GitTree) {
        await _checkoutTree(leafRelativePath, obj, index);
        continue;
      }

      assert(obj is GitBlob);

      var blob = obj as GitBlob;
      var blobPath = p.join(workTree, leafRelativePath);

      await fs.directory(p.dirname(blobPath)).create(recursive: true);
      await fs.file(blobPath).writeAsBytes(blob.blobData);

      await addFileToIndex(index, blobPath);
      updated++;
    }

    // FIXME: What about removing the files from the prev tree?

    return updated;
  }

  /// Create a new branch with `branchName` which points to `hash`
  /// and changes the workTree to match the hash
  /// and updates HEAD to point to it
  Future<void> checkoutBranch(String branchName, GitHash hash) async {
    await createBranch(branchName, hash);
    var obj = await objStorage.readObjectFromHash(hash);
    var commit = obj as GitCommit;
    var treeObj = await objStorage.readObjectFromHash(commit.treeHash);

    var index = GitIndex(versionNo: 2);
    await _checkoutTree('', treeObj, index);
    await writeIndex(index);

    // Set HEAD to to it
    var refName = ReferenceName.head(branchName);
    await fs
        .file(p.join(gitDir, 'HEAD'))
        .writeAsString('ref: ${refName.value}\n');
  }

  Future<GitHash> deleteBranch(String branchName) async {
    var refName = ReferenceName.head(branchName);
    var ref = await refStorage.reference(refName);
    if (ref == null) {
      return null;
    }

    await refStorage.deleteReference(refName);
    return ref.hash;
  }

  String _normalizePath(String path) {
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

// Sort allDirs on bfs
@visibleForTesting
int dirSortFunc(String a, String b) {
  var aCnt = '/'.allMatches(a).length;
  var bCnt = '/'.allMatches(b).length;
  if (aCnt != bCnt) {
    if (aCnt < bCnt) return -1;
    if (aCnt > bCnt) return 1;
  }
  if (a.isEmpty && b.isEmpty) return 0;
  if (a.isEmpty) {
    return -1;
  }
  if (b.isEmpty) {
    return 1;
  }
  return a.compareTo(b);
}
