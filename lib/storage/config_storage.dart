import 'package:dart_git/config.dart';
import 'package:dart_git/utils/result.dart';

abstract class ConfigStorage {
  Future<Result<Config>> readConfig();
  Future<Result<bool>> exists();

  Future<Result<void>> writeConfig(Config config);
}
