import 'package:dart_git/config.dart';
import 'package:dart_git/utils/result.dart';
import 'interfaces.dart';

class ConfigStorageExceptionCatcher implements ConfigStorage {
  final ConfigStorage _;

  ConfigStorageExceptionCatcher({required ConfigStorage storage}) : _ = storage;

  @override
  Result<Config> readConfig() => catchAllSync(() => _.readConfig());

  @override
  Result<bool> exists() => catchAllSync(() => _.exists());

  @override
  Result<void> writeConfig(Config config) =>
      catchAllSync(() => _.writeConfig(config));
}
