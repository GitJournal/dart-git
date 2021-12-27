import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/storage/interfaces.dart';
import 'package:dart_git/utils/result.dart';

class ReferenceStorageExceptionCatcher implements ReferenceStorage {
  final ReferenceStorage _;

  ReferenceStorageExceptionCatcher({required ReferenceStorage storage})
      : _ = storage;

  @override
  Result<Reference> reference(ReferenceName refName) =>
      catchAllSync(() => _.reference(refName));

  @override
  Result<List<Reference>> listReferences(String prefix) =>
      catchAllSync(() => _.listReferences(prefix));

  @override
  Result<void> saveRef(Reference ref) => catchAllSync(() => _.saveRef(ref));

  @override
  Result<void> removeReferences(String prefix) =>
      catchAllSync(() => _.removeReferences(prefix));

  @override
  Result<void> deleteReference(ReferenceName refName) =>
      catchAllSync(() => _.deleteReference(refName));
}
