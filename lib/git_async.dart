import 'dart:isolate';

import 'package:file/file.dart';
import 'package:tuple/tuple.dart';

import 'package:dart_git/config.dart';
import 'package:dart_git/git.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/objects/commit.dart';
import 'package:dart_git/plumbing/reference.dart';

class GitAsyncRepository {
  final Isolate _isolate;
  final Stream<dynamic> _receiveStream;
  final SendPort _sendPort;
  final ReceivePort _receivePort;
  final ReceivePort _exitPort;
  final ReceivePort _errorPort;

  final Config _config;
  bool open = true;

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

  static Future<Result<GitAsyncRepository>> load(
    String gitRootDir, {
    FileSystem? fs,
  }) async {
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

    dynamic _;
    _ = exitR.listen((message) => print("exit: $message"));
    _ = errorR.listen((message) => print("error: $message"));

    var receiveStream = receivePort.asBroadcastStream();
    var data = await receiveStream.first;

    assert(data is SendPort);
    var sendPort = data as SendPort;
    sendPort.send(_LoadInput(gitRootDir, fs));

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
      return Result(repo);
    }

    assert(resp is _ErrorMsg);
    var errMsg = resp as _ErrorMsg;
    return Result.fail(errMsg.item1, errMsg.item2);
  }

  void close() {
    open = false;
    _receivePort.close();
    _errorPort.close();
    _exitPort.close();

    _isolate.kill();
  }

  Future<dynamic> _compute(_Command cmd, dynamic inputData) async {
    assert(open);

    _sendPort.send(_InputMsg(cmd, inputData));
    var output = await _receiveStream.first as _OutputMsg;

    assert(output.command == cmd);
    assert(output.result is Result);
    return output.result;
  }

  Future<Result<List<String>>> branches() async =>
      await _compute(_Command.branches, null);

  Future<Result<String>> currentBranch() async =>
      await _compute(_Command.currentBranch, null);

  Future<Result<BranchConfig>> setUpstreamTo(
    GitRemoteConfig remote,
    String remoteBranchName,
  ) async =>
      await _compute(
        _Command.setUpstreamTo,
        _SetUpstreamToInput(remote, remoteBranchName),
      );

  Future<Result<BranchConfig>> setBranchUpstreamTo(String branchName,
          GitRemoteConfig remote, String remoteBranchName) async =>
      await _compute(
        _Command.setBranchUpstreamTo,
        _SetBranchUpstreamToInput(branchName, remote, remoteBranchName),
      );

  Future<Result<GitHash>> createBranch(
    String name, {
    GitHash? hash,
    bool overwrite = false,
  }) async =>
      await _compute(
        _Command.createBranch,
        _CreateBranchInput(name, hash, overwrite),
      );

  Future<Result<GitHash>> deleteBranch(String branchName) async =>
      await _compute(_Command.deleteBranch, branchName);

  Future<Result<GitCommit>> headCommit() async =>
      await _compute(_Command.headCommit, null);

  Future<Result<GitHash>> headHash() async =>
      await _compute(_Command.headHash, null);

  Future<Result<bool>> canPush() async =>
      await _compute(_Command.canPush, null);

  Future<Result<int>> numChangesToPush() async =>
      await _compute(_Command.numChangesToPush, null);

  //
  // index.dart
  //

  Future<Result<void>> add(String pathSpec) async =>
      await _compute(_Command.add, pathSpec);

  Future<Result<void>> rm(String pathSpec, {bool rmFromFs = true}) async =>
      await _compute(_Command.rm, _RemoveInput(pathSpec, rmFromFs));

  //
  // checkout.dart
  //

  Future<Result<int>> checkout(String path) async =>
      await _compute(_Command.checkout, path);

  Future<Result<Reference>> checkoutBranch(String branchName) async =>
      await _compute(_Command.checkoutBranch, branchName);

  //
  // commit.dart
  //

  Future<Result<GitCommit>> commit({
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
  Future<Result<void>> mergeCurrentTrackingBranch({
    required GitAuthor author,
  }) async =>
      await _compute(_Command.mergeCurrentTrackingBranch, author);

  //
  // reset.dart
  //
  Future<Result<void>> resetHard(GitHash hash) async =>
      await _compute(_Command.resetHard, hash);

  //
  // remotes.dart
  //

  Future<Result<List<Reference>>> remoteBranches(String remoteName) async =>
      await _compute(_Command.remoteBranches, remoteName);

  Future<Result<Reference>> remoteBranch(
    String remoteName,
    String branchName,
  ) async =>
      await _compute(
        _Command.remoteBranch,
        _DoubleString(remoteName, branchName),
      );

  Future<Result<GitRemoteConfig>> addRemote(String name, String url) async =>
      await _compute(
        _Command.addRemote,
        _DoubleString(name, url),
      );

  Future<Result<GitRemoteConfig>> addOrUpdateRemote(
    String name,
    String url,
  ) async =>
      await _compute(
        _Command.addOrUpdateRemote,
        _DoubleString(name, url),
      );

  Future<Result<GitRemoteConfig>> removeRemote(String name) async =>
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

  mergeCurrentTrackingBranch,
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

  _OutputMsg(this.command, this.result) {
    assert(result is Result);
  }
}

typedef _LoadInput = Tuple2<String, FileSystem?>;
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

  var repoLoadR = GitRepository.load(gitRootDir, fs: fs);
  if (repoLoadR.isFailure) {
    toMainSender.send(_ErrorMsg(repoLoadR.error!, repoLoadR.stackTrace!));
    return;
  }
  var repo = repoLoadR.getOrThrow();
  toMainSender.send(repo.config);

  var _ = fromMainRec.listen((msg) {
    var input = msg as _InputMsg;
    var out = _processCommand(repo, input);
    toMainSender.send(_OutputMsg(input.command, out));
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

    case _Command.mergeCurrentTrackingBranch:
      return repo.mergeCurrentTrackingBranch(author: input.data);

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
