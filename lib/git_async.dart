import 'dart:isolate';

import 'package:dart_git/git.dart';
import 'package:file/file.dart';
import 'package:tuple/tuple.dart';

class GitAsyncRepository {
  final Isolate _isolate;
  final Stream<dynamic> _receiveStream;
  final SendPort _sendPort;
  final ReceivePort _receivePort;
  final ReceivePort _exitPort;
  final ReceivePort _errorPort;

  GitAsyncRepository._(
    this._isolate,
    this._receiveStream,
    this._sendPort,
    this._receivePort,
    this._exitPort,
    this._errorPort,
  );

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
    if (resp is bool) {
      var repo = GitAsyncRepository._(
        isolate,
        receiveStream,
        sendPort,
        receivePort,
        exitR,
        errorR,
      );
      return Result(repo);
    }

    assert(resp is _ErrorMsg);
    var errMsg = resp as _ErrorMsg;
    return Result.fail(errMsg.item1, errMsg.item2);
  }

  void close() {
    _receivePort.close();
    _errorPort.close();
    _exitPort.close();

    _isolate.kill();
  }

  Future<dynamic> _compute(_Command cmd, dynamic inputData) async {
    _sendPort.send(_InputMsg(cmd, inputData));
    var output = await _receiveStream.first as _OutputMsg;

    assert(output.command == cmd);
    assert(output.result is Result);
    return output.result;
  }

  Future<Result<List<String>>> branches() async =>
      await _compute(_Command.Branches, null);

  Future<Result<String>> currentBranch() async =>
      await _compute(_Command.CurrentBranch, null);
}

enum _Command {
  Branches,
  CurrentBranch,
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
  toMainSender.send(true);
  var repo = repoLoadR.getOrThrow();

  var _ = fromMainRec.listen((msg) async {
    var input = msg as _InputMsg;
    var cmd = input.command;

    switch (cmd) {
      case _Command.Branches:
        var out = repo.branches();
        toMainSender.send(_OutputMsg(cmd, out));
        break;

      case _Command.CurrentBranch:
        var out = repo.currentBranch();
        toMainSender.send(_OutputMsg(cmd, out));
        break;
    }
  });
}
