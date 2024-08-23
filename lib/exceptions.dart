import 'package:dart_git/plumbing/git_hash.dart';
import 'package:dart_git/plumbing/reference.dart';

class GitException implements Exception {}

class GitNotFound implements GitException {}

class InvalidRepoException implements GitException {
  String path;
  InvalidRepoException(this.path);

  @override
  String toString() => 'Not a Git Repository: $path';
}

class GitFatalException implements GitException {}

class PathSpecOutsideRepoException implements GitFatalException {
  final String pathSpec;

  PathSpecOutsideRepoException({required this.pathSpec});

  @override
  String toString() => "fatal: $pathSpec: '$pathSpec' is outside repository";
}

class GitIndexCorruptedException implements GitFatalException {
  final String reason;

  GitIndexCorruptedException(this.reason);

  @override
  String toString() => 'fatal: GitIndexCorrupted: $reason';
}

class GitIndexHashDifferentException implements GitFatalException {
  final GitHash expected;
  final GitHash actual;

  GitIndexHashDifferentException(
      {required this.expected, required this.actual});

  @override
  String toString() => 'fatal: GitIndexCorrupted: Invalid Hash';
}

class GitHashStringNotHexadecimal implements GitException {}

class GitObjectNotFound implements GitException {
  GitHash hash;
  GitObjectNotFound(this.hash);

  @override
  String toString() => 'GitObjectNotFound: $hash';
}

class GitObjectWithRefSpecNotFound implements GitNotFound {
  String refSpec;
  GitObjectWithRefSpecNotFound(this.refSpec);

  @override
  String toString() => 'GitObjectWithRefSpecNotFound: $refSpec';
}

class GitObjectCorruptedMissingType implements GitException {}

class GitObjectCorruptedMissingSize implements GitException {}

class GitObjectCorruptedInvalidIntSize implements GitException {}

class GitObjectCorruptedBadSize implements GitException {}

class GitHeadDetached implements GitException {}

class GitEmptyCommit implements GitException {}

class GitObjectInvalidType implements GitException {
  String type;
  GitObjectInvalidType(this.type);

  @override
  String toString() => 'GitInvalidType: $type';
}

class GitBranchAlreadyExists implements GitException {
  String name;
  GitBranchAlreadyExists(this.name);

  @override
  String toString() => 'GitBranchAlreadyExists: $name';
}

class GitRemoteAlreadyExists implements GitException {
  String name;
  GitRemoteAlreadyExists(this.name);

  @override
  String toString() => 'GitRemoteAlreadyExists: $name';
}

class GitRefNotFound implements GitNotFound {
  ReferenceName refName;
  GitRefNotFound(this.refName);

  @override
  String toString() => 'GitRefNotFound: $refName';
}

class GitRefNotHash implements GitNotFound {
  ReferenceName refName;
  GitRefNotHash(this.refName);

  @override
  String toString() => 'GitRefNotHash: $refName';
}

class GitMissingHEAD implements GitNotFound {
  GitMissingHEAD();

  @override
  String toString() => 'GitMissingHEAD';
}

class GitRefStoreCorrupted implements GitException {
  GitRefStoreCorrupted();
}

class GitRemoteNotFound implements GitNotFound {
  String name;
  GitRemoteNotFound(this.name);

  @override
  String toString() => 'GitRemoteNotFound: $name';
}

class InvalidFileType implements GitException {
  final String filePath;
  InvalidFileType(this.filePath);

  @override
  String toString() => 'InvalidFileType: $filePath';
}

class GitFileNotFound implements GitNotFound {
  String filePath;
  GitFileNotFound(this.filePath);

  @override
  String toString() => 'GitFileNotFound: $filePath';
}

class GitShouldNotContainFound extends GitException {}

class GitMergeTooManyBases extends GitException {}

class GitMergeOnHashNotAllowed extends GitException {}

class GitMergeNoCommonAncestor extends GitException {}

class GitNotImplemented extends GitException {}

class GitRepoExists implements GitException {}
