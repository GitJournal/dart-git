import 'dart:async';

import 'package:test/test.dart';

import 'package:dart_git/main.dart' as git;

void main() {
  test('remote', () async {
    var printLog = await run('remote');
    expect(printLog, ['origin']);
  });

  test('remote -v', () async {
    var printLog = await run('remote -v');
    expect(printLog, [
      'origin	git@github.com:GitJournal/dart_git.git (fetch)',
      'origin	git@github.com:GitJournal/dart_git.git (push)',
    ]);
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
