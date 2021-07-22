import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/config.dart';
import 'package:dart_git/utils/result.dart';
import 'config_storage.dart';

class ConfigStorageFS implements ConfigStorage {
  final String _gitDir;
  final FileSystem _fs;

  ConfigStorageFS(this._gitDir, this._fs);

  String get _path => p.join(_gitDir, 'config');

  @override
  Future<Result<Config>> readConfig() async {
    var contents = await _fs.file(_path).readAsString();
    var config = Config(contents);

    return Result(config);
  }

  @override
  Future<Result<bool>> exists() async {
    var val = _fs.isFileSync(_path);
    return Result(val);
  }

  @override
  Future<Result<void>> writeConfig(Config config) async {
    // FIXME: Write to another file and then move it!!
    await _fs.file(_path).writeAsString(config.serialize());
    return Result(null);
  }
}
