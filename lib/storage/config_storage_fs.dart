import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/config.dart';
import 'package:dart_git/utils/result.dart';
import 'interfaces.dart';

class ConfigStorageFS implements ConfigStorage {
  final String _gitDir;
  final FileSystem _fs;

  ConfigStorageFS(this._gitDir, this._fs);

  String get _path => p.join(_gitDir, 'config');

  @override
  Result<Config> readConfig() {
    var contents = _fs.file(_path).readAsStringSync();
    var config = Config(contents);

    return Result(config);
  }

  @override
  Result<bool> exists() {
    var val = _fs.isFileSync(_path);
    return Result(val);
  }

  @override
  Result<void> writeConfig(Config config) {
    var path = p.join(_gitDir, '$_path.new');
    var file = _fs.file(path);

    file.writeAsStringSync(config.serialize());
    var _ = file.renameSync(_path);

    return Result(null);
  }
}
