import 'package:dart_git/plumbing/reference.dart';
import 'package:dart_git/storage/interfaces.dart';
import 'package:dart_git/utils/result.dart';

class ReferenceStorageExceptionCatcher implements ReferenceStorage {
  final ReferenceStorage _;

  ReferenceStorageExceptionCatcher({required ReferenceStorage storage})
      : _ = storage;

  @override
  Future<Result<Reference>> reference(ReferenceName refName) =>
      catchAll(() => _.reference(refName));

  @override
  Future<Result<List<Reference>>> listReferences(String prefix) =>
      catchAll(() => _.listReferences(prefix));

  @override
  Future<Result<void>> saveRef(Reference ref) async =>
      catchAll(() => _.saveRef(ref));

  @override
  Future<Result<void>> removeReferences(String prefix) =>
      catchAll(() => _.removeReferences(prefix));

  @override
  Future<Result<void>> deleteReference(ReferenceName refName) =>
      catchAll(() => _.deleteReference(refName));
}
