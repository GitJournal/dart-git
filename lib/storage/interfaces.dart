import 'package:dart_git/config.dart';
import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/index.dart';
import 'package:dart_git/plumbing/objects/object.dart';
import 'package:dart_git/plumbing/reference.dart';

export 'object_storage_extensions.dart';

abstract class ConfigStorage {
  Config readConfig();
  bool exists();

  void writeConfig(Config config);
}

abstract class ReferenceStorage {
  Reference? reference(ReferenceName refName);
  List<Reference> listReferences(String prefix);

  void saveRef(Reference ref);
  void removeReferences(String prefix);
  void deleteReference(ReferenceName refName);

  void close();
}

abstract class ObjectStorage {
  GitObject? read(GitHash hash);
  GitHash writeObject(GitObject obj);

  void close();
}

abstract class IndexStorage {
  GitIndex readIndex();
  void writeIndex(GitIndex index);

  void close();
}
