import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/config.dart';

import 'interfaces.dart';

class ConfigStorageFS implements ConfigStorage {
  final String _gitDir;
  final FileSystem _fs;

  ConfigStorageFS(this._gitDir, this._fs);

  String get _path => p.join(_gitDir, 'config');

  @override
  Config readConfig() {
    var contents = _fs.file(_path).readAsStringSync();
    return Config(contents);
  }

  @override
  bool exists() {
    return _fs.isFileSync(_path);
  }

  @override
  void writeConfig(Config config) {
    var path = p.join(_gitDir, '$_path.new');
    var file = _fs.file(path);

    file.writeAsStringSync(config.serialize());
    file.renameSync(_path);

    return;
  }
}
