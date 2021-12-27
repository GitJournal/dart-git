import 'package:dart_git/config.dart';
import 'package:dart_git/utils/result.dart';
import 'interfaces.dart';

class ConfigStorageExceptionCatcher implements ConfigStorage {
  final ConfigStorage _;

  ConfigStorageExceptionCatcher({required ConfigStorage storage}) : _ = storage;

  @override
  Future<Result<Config>> readConfig() => catchAll(() => _.readConfig());

  @override
  Result<bool> exists() => catchAllSync(() => _.exists());

  @override
  Future<Result<void>> writeConfig(Config config) =>
      catchAll(() => _.writeConfig(config));
}
