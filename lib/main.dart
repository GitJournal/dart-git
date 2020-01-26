import 'git.dart';

void main(List<String> args) async {
  print(args);
  var cmd = args[0];
  if (cmd == 'init') {
    var path = args[1];
    await GitRepository.init(path);
    print('Done');
  }
}
