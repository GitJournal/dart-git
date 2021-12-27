import 'package:dart_git/config.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/utils/result.dart';

export 'object_storage_extensions.dart';

abstract class ConfigStorage {
  Result<Config> readConfig();
  Result<bool> exists();

  Result<void> writeConfig(Config config);
}

abstract class ReferenceStorage {
  Result<Reference> reference(ReferenceName refName);
  Result<List<Reference>> listReferences(String prefix);

  Result<void> saveRef(Reference ref);
  Result<void> removeReferences(String prefix);
  Result<void> deleteReference(ReferenceName refName);
}

abstract class ObjectStorage {
  Result<GitObject> read(GitHash hash);
  Result<GitHash> writeObject(GitObject obj);
}

abstract class IndexStorage {
  Result<GitIndex> readIndex();
  Result<void> writeIndex(GitIndex index);
}
