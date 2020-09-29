import 'dart:async';

import 'package:test/test.dart';

import 'package:dart_git/main.dart' as git;

void main() {
  test('Lists all the Remotes correctly', () async {
    var printLog = await run('remote');
    expect(printLog, ['origin']);
  });
}

Future<List<String>> run(String command) async {
  var printLog = <String>[];

  var spec = ZoneSpecification(print: (_, __, ___, String msg) {
    printLog.add(msg);
  });
  await Zone.current.fork(specification: spec).run(() {
    return git.main(command.split(' '));
  });
  return printLog;
}
