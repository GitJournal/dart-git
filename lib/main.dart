import 'dart:io';
import 'git.dart';

void main(List<String> args) async {
  print(args);
  var cmd = args[0];
  if (cmd == 'init') {
    var path = args[1];
    await GitRepository.init(path);
    print('Done');
  }

  if (cmd == 'cat-file') {
    var sha1 = args[1];

    var repo = GitRepository(Directory.current.path);
    var obj = await repo.readObject(sha1);
    print(obj);
  }
}
