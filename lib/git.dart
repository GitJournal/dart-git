import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/ascii_helper.dart';
import 'package:dart_git/branch.dart';
import 'package:dart_git/config.dart';
import 'package:dart_git/exceptions.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/git_remote.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/blob.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/plumbing/objects/tree.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/storage/reference_storage.dart';

class GitRepository {
  String workTree;
  String gitDir;

  Config config;

  FileSystem fs;
  ReferenceStorage refStorage;

  GitRepository._internal({@required String rootDir, @required this.fs}) {
    workTree = rootDir;
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

    repo.refStorage = ReferenceStorage(repo.gitDir);

    return repo;
  }

  static Future<void> init(String path, {FileSystem fs}) async {
    fs ??= const LocalFileSystem();

    // FIXME: Check if path has stuff and accordingly return

    var gitDir = p.join(path, '.git');

    await fs.directory(p.join(gitDir, 'branches')).create(recursive: true);
    await fs.directory(p.join(gitDir, 'objects')).create(recursive: true);
    await fs.directory(p.join(gitDir, 'refs', 'tags')).create(recursive: true);
    await fs.directory(p.join(gitDir, 'refs', 'heads')).create(recursive: true);

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

  Iterable<Branch> branches() {
    return config.branches.values;
  }

  Branch branch(String name) {
    assert(config.branches.containsKey(name));
    return config.branches[name];
  }

  Future<Branch> currentBranch() async {
    var _head = await head();
    if (_head.isHash) {
      return null;
    }

    return branch(_head.target.branchName());
  }

  Future<Branch> setUpstreamTo(
      GitRemote remote, String remoteBranchName) async {
    var br = await currentBranch();
    br.remote = remote.name;
    br.merge = ReferenceName.head(remoteBranchName);

    await saveConfig();
    return br;
  }

  List<GitRemote> remotes() {
    return config.remotes;
  }

  Future<GitRemote> addRemote(String name, String url) async {
    var existingRemote = config.remotes.firstWhere(
      (r) => r.name == name,
      orElse: () => null,
    );
    if (existingRemote != null) {
      throw Exception('fatal: remote "$name" already exists.');
    }

    var remote = GitRemote();
    remote.name = name;
    remote.url = url;
    remote.fetch = '+refs/heads/*:refs/remotes/$name/*';

    config.remotes.add(remote);
    await saveConfig();

    return remote;
  }

  GitRemote remote(String name) {
    return config.remotes.firstWhere((r) => r.name == name, orElse: () => null);
  }

  Future<GitObject> readObjectFromHash(GitHash hash) async {
    var sha = hash.toString();
    var path = p.join(gitDir, 'objects', sha.substring(0, 2), sha.substring(2));
    return readObjectFromPath(path);
  }

  Future<GitObject> readObjectFromPath(String filePath) async {
    var contents = await fs.file(filePath).readAsBytes();
    var raw = zlib.decode(contents);

    // Read Object Type
    var x = raw.indexOf(asciiHelper.space);
    var fmt = raw.sublist(0, x);

    // Read and validate object size
    var y = raw.indexOf(0x0, x);
    var size = int.parse(ascii.decode(raw.sublist(x, y)));
    if (size != (raw.length - y - 1)) {
      throw Exception('Malformed object $filePath: bad length');
    }

    var fmtStr = ascii.decode(fmt);
    return createObject(fmtStr, raw.sublist(y + 1), filePath);
  }

  Future<GitHash> writeObject(GitObject obj) async {
    var result = obj.serialize();
    var hash = GitHash.compute(result);
    var sha = hash.toString();

    var path = p.join(gitDir, 'objects', sha.substring(0, 2), sha.substring(2));
    await fs.directory(p.dirname(path)).create(recursive: true);
    await fs.file(path).writeAsBytes(zlib.encode(result));

    return hash;
  }

  Future<Reference> head() async {
    return refStorage.reference(ReferenceName('HEAD'));
  }

  Future<Reference> resolveReference(Reference ref) async {
    if (ref.type == ReferenceType.Hash) {
      return ref;
    }

    var resolvedRef = await refStorage.reference(ref.target);
    if (resolvedRef == null) {
      return null;
    }
    return resolveReference(resolvedRef);
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
    var head = await this.head();
    if (head.isHash) {
      return false;
    }

    var branch = this.branch(head.target.branchName());

    // Construct remote's branch
    var remoteBranchName = branch.merge.branchName();
    var remoteRef = ReferenceName.remote(branch.remote, remoteBranchName);

    var headHash = (await resolveReference(head)).hash;
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
        obj = await readObjectFromHash(sha);
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

    var branch = this.branch(head.target.branchName());
    if (branch == null) {
      return 0;
    }

    // Construct remote's branch
    var remoteBranchName = branch.merge.branchName();
    var remoteRef = ReferenceName.remote(branch.remote, remoteBranchName);

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
    var file = fs.file(filePath);
    if (!file.existsSync()) {
      throw Exception("fatal: pathspec '$filePath' did not match any files");
    }

    // Save that file as a blob
    var data = await file.readAsBytes();
    var blob = GitBlob(data, null);
    var hash = await writeObject(blob);

    var pathSpec = filePath;
    if (pathSpec.startsWith(workTree)) {
      pathSpec = filePath.substring(workTree.length + 1);
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

  Future<GitCommit> commit({
    @required String message,
    @required GitAuthor author,
    GitAuthor committer,
    bool addAll = false,
  }) async {
    committer ??= author;

    var index = await readIndex();

    // FIXME: Implement this properly
    if (addAll) {
      await addFileToIndex(index, p.join(workTree, 'hi.txt'));
      await writeIndex(index);
    }

    //
    // Construct the Tree Objects
    //
    var treeObjects = {'': GitTree.empty()};
    index.entries.forEach((entry) {
      var fullPath = entry.path;
      var fileName = p.basename(fullPath);
      var dirName = p.dirname(fullPath);

      // Construct all the tree objects
      var allDirs = <String>[];
      while (dirName != '.') {
        allDirs.add(dirName);
        dirName = p.dirname(dirName);
      }

      for (var dir in allDirs) {
        var mode = GitFileMode.Dir.toString();
        treeObjects.update(dir, (tree) {
          tree.leaves.add(GitTreeLeaf(mode: mode, path: dir, hash: null));
          return tree;
        }, ifAbsent: () {
          var tree = GitTree.empty();
          tree.leaves.add(GitTreeLeaf(mode: mode, path: dir, hash: null));
          return tree;
        });
      }
      // print("AllDirs: $allDirs");
      // print("TreeObjects: $treeObjects");

      dirName = p.dirname(fullPath);
      if (dirName == '.') {
        dirName = '';
      }
      treeObjects[dirName].leaves.add(
            GitTreeLeaf(
              mode: entry.mode.toString(),
              path: fileName,
              hash: entry.hash,
            ),
          );
    });
    assert(treeObjects.containsKey(''));
    // print(treeObjects[''].leaves);

    // Write all the tree objects
    var hashMap = <String, GitHash>{};
    Future<GitHash> constructTreeHash(GitTree tree) async {
      // print('Consturct: $tree');
      for (var i = 0; i < tree.leaves.length; i++) {
        var leaf = tree.leaves[i];
        // print("Leaf: " + leaf.path);
        if (leaf.hash != null) {
          continue;
        }

        assert(leaf.mode == GitFileMode.Dir.toString());

        var hash = hashMap[leaf.path] ??
            await constructTreeHash(treeObjects[leaf.path]);

        tree.leaves[i] = GitTreeLeaf(
          mode: leaf.mode,
          path: leaf.path,
          hash: hash,
        );
        hashMap[leaf.path] = hash;
      }

      return writeObject(tree);
    }

    var treeHash = await constructTreeHash(treeObjects['']);
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

    await writeObject(commit);
    return commit;
  }

  Future<GitHash> writeTree() async {
    return GitHash('sha');
  }
}
