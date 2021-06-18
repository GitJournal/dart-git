import 'package:file/file.dart';
import 'package:path/path.dart' as p;

import 'package:dart_git/config.dart';
import 'package:dart_git/utils/result.dart';

class ConfigStorage {
  final String _gitDir;
  final FileSystem _fs;

  ConfigStorage(this._gitDir, this._fs);

  String get _path => p.join(_gitDir, 'config');

  Future<Result<Config>> readConfig() async {
    var contents = await _fs.file(_path).readAsString();
    var config = Config(contents);

    return Result(config);
  }

  Future<Result<bool>> exists() async {
    var val = _fs.isFileSync(_path);
    return Result(val);
  }

  Future<Result<void>> writeConfig(Config config) async {
    // FIXME: Write to another file and then move it!!
    await _fs.file(_path).writeAsString(config.serialize());
    return Result(null);
  }
}
