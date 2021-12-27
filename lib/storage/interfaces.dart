import 'package:dart_git/config.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/utils/result.dart';

export 'object_storage_extensions.dart';

abstract class ConfigStorage {
  Future<Result<Config>> readConfig();
  Result<bool> exists();

  Future<Result<void>> writeConfig(Config config);
}

abstract class ReferenceStorage {
  Future<Result<Reference>> reference(ReferenceName refName);
  Future<Result<List<Reference>>> listReferences(String prefix);

  Future<Result<void>> saveRef(Reference ref);
  Future<Result<void>> removeReferences(String prefix);
  Future<Result<void>> deleteReference(ReferenceName refName);
}

abstract class ObjectStorage {
  Future<Result<GitObject>> read(GitHash hash);
  Future<Result<GitHash>> writeObject(GitObject obj);
}

abstract class IndexStorage {
  Future<Result<GitIndex>> readIndex();
  Future<Result<void>> writeIndex(GitIndex index);
}
