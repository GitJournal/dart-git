import 'dart:async';
import 'dart:isolate';

import 'package:file/file.dart';
import 'package:synchronized/synchronized.dart';
import 'package:tuple/tuple.dart';

import 'package:dart_git/config.dart';
import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/reference.dart';

final _repos = <String, GitAsyncRepository>{};
final _reposLock = Lock();

class GitAsyncRepository {
  final Isolate _isolate;
  final Stream<dynamic> _receiveStream;
  final SendPort _sendPort;
  final ReceivePort _receivePort;
  final ReceivePort _exitPort;
  final ReceivePort _errorPort;

  final Config _config;

  /// isOpen returns 'true' even if the repo auto closes
  bool get isOpen => _open;
  bool _open = true;

  final _lock = Lock();

  GitAsyncRepository._(
    this._isolate,
    this._receiveStream,
    this._sendPort,
    this._receivePort,
    this._exitPort,
    this._errorPort,
    this._config,
  );

  Config get config => _config;

  /// Disable autoClose by passing null
  static Future<GitAsyncRepository> load(
    String repoPath, {
    FileSystem? fs,
    bool reuseIsolate = true,
    Duration? autoCloseDuration = const Duration(seconds: 5),
  }) async {
    if (reuseIsolate) {
      return _reposLock.synchronized(() => _load(
            repoPath,
            fs: fs,
            reuseIsolate: reuseIsolate,
            autoCloseDuration: autoCloseDuration,
          ));
    }

    return _load(
      repoPath,
      fs: fs,
      reuseIsolate: reuseIsolate,
      autoCloseDuration: autoCloseDuration,
    );
  }

  static Future<GitAsyncRepository> _load(
    String repoPath, {
    required FileSystem? fs,
    required bool reuseIsolate,
    required Duration? autoCloseDuration,
  }) async {
    if (reuseIsolate) {
      var r = _repos[repoPath];
      if (r != null && r.isOpen) {
        return r;
      }
    }

    var receivePort = ReceivePort('GitAsyncRepository_toIsolate');
    var exitR = ReceivePort('GitAsyncRepository_exit');
    var errorR = ReceivePort('GitAsyncRepository_error');

    var isolate = await Isolate.spawn(
      _isolateMain,
      receivePort.sendPort,
      errorsAreFatal: true,
      debugName: 'GitAsyncRepository',
      onExit: exitR.sendPort,
      onError: errorR.sendPort,
    );

    exitR.listen((_) async {
      return _reposLock.synchronized(() => _repos.remove(repoPath));
    });
    // ignore: avoid_print
    errorR.listen((message) => print("GitAsyncRepo Error: $message"));

    var receiveStream = receivePort.asBroadcastStream();
    var data = await receiveStream.first;

    assert(data is SendPort);
    var sendPort = data as SendPort;
    sendPort.send(_LoadInput(repoPath, fs, autoCloseDuration));

    var resp = await receiveStream.first;
    if (resp is Config) {
      var repo = GitAsyncRepository._(
        isolate,
        receiveStream,
        sendPort,
        receivePort,
        exitR,
        errorR,
        resp,
      );

      if (reuseIsolate) {
        _repos[repoPath] = repo;
      }
      return repo;
    }

    assert(resp is _ErrorMsg);
    var errMsg = resp as _ErrorMsg;
    Error.throwWithStackTrace(errMsg.item1, errMsg.item2);
  }

  void close() {
    _open = false;
    _receivePort.close();
    _errorPort.close();
    _exitPort.close();

    _isolate.kill();
  }

  Future<dynamic> _compute(_Command cmd, dynamic inputData) async {
    assert(_open);

    return _lock.synchronized(() async {
      _sendPort.send(_InputMsg(cmd, inputData));
      var output = await _receiveStream.first;
      if (output is _OutputMsg) {
        assert(output.command == cmd, "Actual: ${output.command}, Exp: $cmd");
        return output.result;
      } else if (output is _ErrorMsg) {
        Error.throwWithStackTrace(output.item1, output.item2);
      } else {
        throw "Unknown output: $output";
      }
    });
  }

  Future<List<String>> branches() async =>
      await _compute(_Command.branches, null);

  Future<String> currentBranch() async =>
      await _compute(_Command.currentBranch, null);

  Future<BranchConfig> setUpstreamTo(
    GitRemoteConfig remote,
    String remoteBranchName,
  ) async =>
      await _compute(
        _Command.setUpstreamTo,
        _SetUpstreamToInput(remote, remoteBranchName),
      );

  Future<BranchConfig> setBranchUpstreamTo(String branchName,
          GitRemoteConfig remote, String remoteBranchName) async =>
      await _compute(
        _Command.setBranchUpstreamTo,
        _SetBranchUpstreamToInput(branchName, remote, remoteBranchName),
      );

  Future<GitHash> createBranch(
    String name, {
    GitHash? hash,
    bool overwrite = false,
  }) async =>
      await _compute(
        _Command.createBranch,
        _CreateBranchInput(name, hash, overwrite),
      );

  Future<GitHash> deleteBranch(String branchName) async =>
      await _compute(_Command.deleteBranch, branchName);

  Future<GitCommit> headCommit() async =>
      await _compute(_Command.headCommit, null);

  Future<GitHash> headHash() async => await _compute(_Command.headHash, null);

  Future<bool> canPush() async => await _compute(_Command.canPush, null);

  Future<int> numChangesToPush() async =>
      await _compute(_Command.numChangesToPush, null);

  //
  // index.dart
  //

  Future<void> add(String pathSpec) async => _compute(_Command.add, pathSpec);

  Future<void> rm(String pathSpec, {bool rmFromFs = true}) async =>
      _compute(_Command.rm, _RemoveInput(pathSpec, rmFromFs));

  //
  // checkout.dart
  //

  Future<int> checkout(String path) async =>
      await _compute(_Command.checkout, path);

  Future<HashReference> checkoutBranch(String branchName) async =>
      await _compute(_Command.checkoutBranch, branchName);

  //
  // commit.dart
  //

  Future<GitCommit> commit({
    required String message,
    required GitAuthor author,
    GitAuthor? committer,
    bool addAll = false,
  }) async =>
      await _compute(
        _Command.commit,
        _CommitInput(message, author, committer, addAll),
      );

  //
  // merge.dart
  //
  Future<void> mergeCurrentTrackingBranch({
    required GitAuthor author,
  }) async =>
      _compute(_Command.mergeTrackingBranch, author);

  //
  // reset.dart
  //
  Future<void> resetHard(GitHash hash) async =>
      _compute(_Command.resetHard, hash);

  //
  // remotes.dart
  //

  Future<List<Reference>> remoteBranches(String remoteName) async =>
      await _compute(_Command.remoteBranches, remoteName);

  Future<Reference> remoteBranch(
    String remoteName,
    String branchName,
  ) async =>
      await _compute(
        _Command.remoteBranch,
        _DoubleString(remoteName, branchName),
      );

  Future<GitRemoteConfig> addRemote(String name, String url) async =>
      await _compute(
        _Command.addRemote,
        _DoubleString(name, url),
      );

  Future<GitRemoteConfig> addOrUpdateRemote(
    String name,
    String url,
  ) async =>
      await _compute(
        _Command.addOrUpdateRemote,
        _DoubleString(name, url),
      );

  Future<GitRemoteConfig> removeRemote(String name) async =>
      await _compute(_Command.removeRemote, name);
}

enum _Command {
  branches,
  currentBranch,
  setUpstreamTo,
  setBranchUpstreamTo,
  createBranch,
  deleteBranch,

  checkout,
  checkoutBranch,

  headHash,
  headCommit,
  canPush,
  numChangesToPush,

  add,
  rm,
  commit,

  mergeTrackingBranch,
  resetHard,

  remoteBranches,
  remoteBranch,
  addRemote,
  addOrUpdateRemote,
  removeRemote,
}

class _InputMsg {
  _Command command;
  dynamic data;

  _InputMsg(this.command, this.data);
}

class _OutputMsg {
  _Command command;
  dynamic result;

  _OutputMsg(this.command, this.result);
}

typedef _LoadInput = Tuple3<String, FileSystem?, Duration?>;
typedef _ErrorMsg = Tuple2<Object, StackTrace>;
typedef _RemoveInput = Tuple2<String, bool>;
typedef _CommitInput = Tuple4<String, GitAuthor, GitAuthor?, bool>;
typedef _DoubleString = Tuple2<String, String>;
typedef _SetUpstreamToInput = Tuple2<GitRemoteConfig, String>;
typedef _SetBranchUpstreamToInput = Tuple3<String, GitRemoteConfig, String>;
typedef _CreateBranchInput = Tuple3<String, GitHash?, bool>;

Future<void> _isolateMain(SendPort toMainSender) async {
  ReceivePort rp = ReceivePort('GitAsyncRepository_fromIsolate');
  toMainSender.send(rp.sendPort);
  var fromMainRec = rp.asBroadcastStream();

  var input = await fromMainRec.first as _LoadInput;
  var gitRootDir = input.item1;
  var fs = input.item2;
  var autoCloseDuration = input.item3;

  late GitRepository repo;
  try {
    repo = GitRepository.load(gitRootDir, fs: fs);
  } catch (e, st) {
    toMainSender.send(_ErrorMsg(e, st));
    return;
  }
  toMainSender.send(repo.config);

  var lastCommandTime = DateTime.now();
  if (autoCloseDuration != null && autoCloseDuration.inMicroseconds > 0) {
    Timer.periodic(autoCloseDuration, (timer) {
      var duration = DateTime.now().difference(lastCommandTime);
      if (duration >= autoCloseDuration) {
        rp.close();
        timer.cancel();
        Isolate.exit();
      }
    });
  }

  fromMainRec.listen((msg) {
    var input = msg as _InputMsg;
    try {
      var out = _processCommand(repo, input);
      toMainSender.send(_OutputMsg(input.command, out));
    } catch (ex, st) {
      toMainSender.send(_ErrorMsg(ex, st));
    }

    lastCommandTime = DateTime.now();
  });
}

dynamic _processCommand(GitRepository repo, _InputMsg input) {
  var cmd = input.command;

  switch (cmd) {
    case _Command.branches:
      return repo.branches();

    case _Command.currentBranch:
      return repo.currentBranch();

    case _Command.setUpstreamTo:
      var data = input.data as _SetUpstreamToInput;
      return repo.setUpstreamTo(data.item1, data.item2);

    case _Command.setBranchUpstreamTo:
      var data = input.data as _SetBranchUpstreamToInput;
      return repo.setBranchUpstreamTo(data.item1, data.item2, data.item3);

    case _Command.createBranch:
      var data = input.data as _CreateBranchInput;
      return repo.createBranch(data.item1,
          hash: data.item2, overwrite: data.item3);

    case _Command.deleteBranch:
      return repo.deleteBranch(input.data);

    case _Command.checkout:
      return repo.checkout(input.data);

    case _Command.checkoutBranch:
      return repo.checkoutBranch(input.data);

    case _Command.headHash:
      return repo.headHash();

    case _Command.headCommit:
      return repo.headCommit();

    case _Command.canPush:
      return repo.canPush();

    case _Command.numChangesToPush:
      return repo.numChangesToPush();

    case _Command.add:
      return repo.add(input.data);

    case _Command.rm:
      var data = input.data as _RemoveInput;
      return repo.rm(data.item1, rmFromFs: data.item2);

    case _Command.commit:
      var data = input.data as _CommitInput;
      return repo.commit(
        message: data.item1,
        author: data.item2,
        committer: data.item3,
        addAll: data.item4,
      );

    case _Command.mergeTrackingBranch:
      return repo.mergeTrackingBranch(author: input.data);

    case _Command.resetHard:
      return repo.resetHard(input.data);

    case _Command.remoteBranches:
      return repo.remoteBranches(input.data);

    case _Command.remoteBranch:
      var data = input.data as _DoubleString;
      return repo.remoteBranch(data.item1, data.item2);

    case _Command.addRemote:
      var data = input.data as _DoubleString;
      return repo.addRemote(data.item1, data.item2);

    case _Command.addOrUpdateRemote:
      var data = input.data as _DoubleString;
      return repo.addOrUpdateRemote(data.item1, data.item2);

    case _Command.removeRemote:
      return repo.removeRemote(input.data);
  }
}
