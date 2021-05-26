import 'package:dart_git/plumbing/git_hash.dart';

class GitException implements Exception {}

class InvalidRepoException implements GitException {
  String path;
  InvalidRepoException(this.path);

  @override
  String toString() => 'Not a Git Repository: ' + path;
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

class GitHashStringNotHexadecimal implements GitException {}

class GitObjectNotFound implements GitException {
  GitHash hash;
  GitObjectNotFound(this.hash);

  @override
  String toString() => 'GitObjectNotFound: $hash';
}

class GitObjectWithRefSpecNotFound implements GitException {
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

class GitRemoteNotFound implements GitException {
  String name;
  GitRemoteNotFound(this.name);

  @override
  String toString() => 'GitRemoteNotFound: $name';
}
