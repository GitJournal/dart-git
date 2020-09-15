import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/ascii_helper.dart';
import 'package:dart_git/branch.dart';
import 'package:dart_git/config.dart';
import 'package:dart_git/git_hash.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/remote.dart';
import 'package:dart_git/storage/reference_storage.dart';

class GitRepository {
  String workTree;
  String gitDir;

  Config config;

  ReferenceStorage refStorage;

  GitRepository(String path) {
    // FIXME: Check if .git exists and if it doesn't go up until it does?
    workTree = path;
    gitDir = p.join(workTree, '.git');

    /*if (!FileSystemEntity.isDirectorySync(gitDir)) {
      throw InvalidRepoException(path);
    }*/
  }

  static String findRootDir(String path) {
    while (true) {
      var gitDir = p.join(path, '.git');
      if (FileSystemEntity.isDirectorySync(gitDir)) {
        return path;
      }

      if (path == p.separator) {
        break;
      }

      path = p.dirname(path);
    }
    return null;
  }

  static Future<GitRepository> load(String gitRootDir) async {
    var repo = GitRepository(gitRootDir);

    var configPath = p.join(repo.gitDir, 'config');
    var configFileContents = await File(configPath).readAsString();
    repo.config = Config(configFileContents);

    repo.refStorage = ReferenceStorage(repo.gitDir);

    return repo;
  }

  static Future<void> init(String path) async {
    // FIXME: Check if path has stuff and accordingly return

    var gitDir = p.join(path, '.git');

    await Directory(p.join(gitDir, 'branches')).create(recursive: true);
    await Directory(p.join(gitDir, 'objects')).create(recursive: true);
    await Directory(p.join(gitDir, 'refs', 'tags')).create(recursive: true);
    await Directory(p.join(gitDir, 'refs', 'heads')).create(recursive: true);

    await File(p.join(gitDir, 'description')).writeAsString(
        "Unnamed repository; edit this file 'description' to name the repository.\n");
    await File(p.join(gitDir, 'HEAD'))
        .writeAsString('ref: refs/heads/master\n');

    var config = Config('');
    var core = config.section('core');
    core.options['repositoryformatversion'] = '0';
    core.options['filemode'] = 'false';
    core.options['bare'] = 'false';

    await File(p.join(gitDir, 'config')).writeAsString(config.serialize());
  }

  Future<void> saveConfig() {
    return File(p.join(gitDir, 'config')).writeAsString(config.serialize());
  }

  Iterable<Branch> branches() {
    return config.branches.values;
  }

  Branch branch(String name) {
    assert(config.branches.containsKey(name));
    return config.branches[name];
  }

  List<Remote> remotes() {
    return config.remotes;
  }

  Remote remote(String name) {
    return config.remotes.firstWhere((r) => r.name == name, orElse: () => null);
  }

  Future<GitObject> readObjectFromHash(GitHash hash) async {
    var sha = hash.toString();
    var path = p.join(gitDir, 'objects', sha.substring(0, 2), sha.substring(2));
    return readObjectFromPath(path);
  }

  Future<GitObject> readObjectFromPath(String filePath) async {
    var contents = await File(filePath).readAsBytes();
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
    await Directory(p.dirname(path)).create(recursive: true);
    await File(path).writeAsBytes(zlib.encode(result));

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
    var path = p.join(gitDir, 'index');
    var bytes = await File(path).readAsBytes();
    return GitIndex.decode(bytes);
  }

  Future<void> writeIndex(GitIndex index) async {
    var path = p.join(gitDir, 'index.new');
    var file = File(path);
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
    var file = File(filePath);
    if (!file.existsSync()) {
      throw Exception("fatal: pathspec '$filePath' did not match any files");
    }

    // Save that file as a blob
    var data = await file.readAsBytes();
    var blob = GitBlob(data, null);
    var hash = await writeObject(blob);

    var pathSpec = filePath;

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
}

class GitException implements Exception {}

class InvalidRepoException implements GitException {
  String path;
  InvalidRepoException(this.path);

  @override
  String toString() => 'Not a Git Repository: ' + path;
}

abstract class GitObject {
  List<int> serialize() {
    var data = serializeData();
    var result = [
      ...format(),
      asciiHelper.space,
      ...ascii.encode(data.length.toString()),
      0x0,
      ...data,
    ];

    //assert(GitHash.compute(result) == hash());
    return result;
  }

  List<int> serializeData();
  List<int> format();

  GitHash hash();
}

class GitBlob extends GitObject {
  static const String fmt = 'blob';
  static final List<int> _fmt = ascii.encode(fmt);

  final List<int> blobData;
  final GitHash _hash;

  GitBlob(this.blobData, this._hash);

  @override
  List<int> serializeData() => blobData;

  @override
  List<int> format() => _fmt;

  @override
  GitHash hash() => _hash ?? GitHash.compute(serialize());
}

class Author {
  String name;
  String email;
  int timestamp;
  int timezoneOffset;
  DateTime date;

  static Author parse(String input) {
    // Regex " AuthorName <Email>  timestamp timeOffset"
    var pattern = RegExp(r'(.*) <(.*)> (\d+) ([+\-]\d\d\d\d)');
    var match = pattern.allMatches(input).toList();

    var author = Author();
    author.name = match[0].group(1);
    author.email = match[0].group(2);
    author.timestamp = (int.parse(match[0].group(3))) * 1000;
    author.date =
        DateTime.fromMillisecondsSinceEpoch(author.timestamp, isUtc: true);
    author.timezoneOffset = int.parse(match[0].group(4));
    return author;
  }

  String serialize() {
    var timestamp = date.toUtc().millisecondsSinceEpoch / 1000;
    var offset = timezoneOffset > 0
        ? '+${timezoneOffset.toString().padLeft(4, "0")}'
        : '-${timezoneOffset.abs().toString().padLeft(4, "0")}';

    return '$name <$email> ${timestamp.toInt()} $offset';
  }

  @override
  String toString() {
    if (timestamp != 0) {
      return 'Author(name: $name, email: $email, date: $date)';
    }
    return 'Author(name: $name, email: $email)';
  }
}

class GitCommit extends GitObject {
  static const String fmt = 'commit';
  static final List<int> _fmt = ascii.encode(fmt);

  Author author;
  Author committer;
  String message;
  GitHash treeHash;
  List<GitHash> parents = [];
  String gpgSig;

  final GitHash _hash;

  GitCommit(List<int> rawData, this._hash) {
    var map = kvlmParse(rawData);
    message = map['_'];
    author = Author.parse(map['author']);
    committer = Author.parse(map['committer']);

    if (map.containsKey('parent')) {
      var parent = map['parent'];
      if (parent is List) {
        parent.forEach((p) => parents.add(GitHash(p as String)));
      } else if (parent is String) {
        parents.add(GitHash(parent));
      } else {
        throw Exception('Unknow parent type');
      }
    }
    treeHash = GitHash(map['tree']);
    gpgSig = map['gpgsig'] ?? '';
  }

  @override
  List<int> serializeData() {
    var map = <String, dynamic>{
      'tree': treeHash.toString(),
    };

    if (parents.length == 1) {
      map['parent'] = parents[0].toString();
    } else {
      map['parent'] = parents.map((e) => e.toString()).toList();
    }
    map['author'] = author.serialize();
    map['committer'] = committer.serialize();
    if (gpgSig.isNotEmpty) {
      map['gpgsig'] = gpgSig;
    }

    map['_'] = message;

    return kvlmSerialize(map);
  }

  @override
  List<int> format() => _fmt;

  @override
  GitHash hash() => _hash ?? GitHash.compute(serialize());
}

Map<String, dynamic> kvlmParse(List<int> raw) {
  var dict = <String, dynamic>{};

  var start = 0;
  while (true) {
    var spaceIndex = raw.indexOf(asciiHelper.space, start);
    var newLineIndex = raw.indexOf(asciiHelper.newLine, start);

    if (newLineIndex < spaceIndex) {
      assert(newLineIndex == start);

      dict['_'] = utf8.decode(raw.sublist(start + 1));
      break;
    }

    var key = raw.sublist(start, spaceIndex);
    var end = spaceIndex;
    while (true) {
      end = raw.indexOf(asciiHelper.newLine, end + 1);
      if (raw[end + 1] != asciiHelper.space) {
        break;
      }
    }

    var value = raw.sublist(spaceIndex + 1, end);
    var valueStr = utf8.decode(value).replaceAll('\n ', '\n');

    var keyStr = utf8.decode(key);
    if (dict.containsKey(keyStr)) {
      var dictVal = dict[keyStr];
      if (dictVal is List) {
        dict[keyStr] = [...dictVal, valueStr];
      } else {
        dict[keyStr] = [dictVal, valueStr];
      }
    } else {
      dict[keyStr] = valueStr;
    }

    start = end + 1;
  }

  return dict;
}

List<int> kvlmSerialize(Map<String, dynamic> kvlm) {
  var ret = <int>[];

  kvlm.forEach((key, val) {
    if (key == '_') {
      return;
    }

    if (val is! List) {
      val = [val];
    }

    val.forEach((v) {
      ret.addAll([
        ...utf8.encode(key),
        asciiHelper.space,
        ...utf8.encode(v.replaceAll('\n', '\n ')),
        asciiHelper.newLine,
      ]);
    });
  });

  ret.addAll([asciiHelper.newLine, ...utf8.encode(kvlm['_'])]);
  return ret;
}

class GitTreeLeaf extends Equatable {
  final String mode;
  final String path;
  final GitHash hash;

  GitTreeLeaf({@required this.mode, @required this.path, @required this.hash});

  @override
  List<Object> get props => [mode, path, hash];

  @override
  bool get stringify => true;
}

class GitTree extends GitObject {
  static const String fmt = 'tree';
  static final List<int> _fmt = ascii.encode(fmt);

  final GitHash _hash;
  List<GitTreeLeaf> leaves = [];

  GitTree(List<int> raw, this._hash) {
    var start = 0;
    while (start < raw.length) {
      var x = raw.indexOf(asciiHelper.space, start);
      assert(x - start == 5 || x - start == 6);

      var mode = raw.sublist(start, x);
      var y = raw.indexOf(0, x);
      var path = raw.sublist(x + 1, y);
      var hashBytes = raw.sublist(y + 1, y + 21);

      var leaf = GitTreeLeaf(
        mode: ascii.decode(mode),
        path: utf8.decode(path),
        hash: GitHash.fromBytes(hashBytes),
      );

      leaves.add(leaf);

      start = y + 21;
    }
  }

  @override
  List<int> serializeData() {
    var data = <int>[];

    for (var leaf in leaves) {
      data.addAll(ascii.encode(leaf.mode));
      data.add(asciiHelper.space);
      data.addAll(utf8.encode(leaf.path));
      data.add(0x00);
      data.addAll(leaf.hash.bytes);
    }

    return data;
  }

  @override
  List<int> format() => _fmt;

  @override
  GitHash hash() => _hash ?? GitHash.compute(serialize());
}

GitObject createObject(String fmt, List<int> rawData, [String filePath]) {
  if (fmt == GitBlob.fmt) {
    return GitBlob(rawData, null);
  } else if (fmt == GitCommit.fmt) {
    return GitCommit(rawData, null);
  } else if (fmt == GitTree.fmt) {
    return GitTree(rawData, null);
  } else {
    throw Exception('Unknown type $fmt for object $filePath');
  }
}
