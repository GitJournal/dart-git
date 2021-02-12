import 'package:meta/meta.dart';

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

  PathSpecOutsideRepoException({@required this.pathSpec});

  @override
  String toString() => "fatal: $pathSpec: '$pathSpec' is outside repository";
}

class PathSpecInvalidException implements GitFatalException {
  final String pathSpec;

  PathSpecInvalidException({@required this.pathSpec});

  @override
  String toString() => "fatal: pathspec '$pathSpec' did not match any files";
}

class BranchAlreadyExistsException implements GitFatalException {
  final String branchName;

  BranchAlreadyExistsException(this.branchName);

  @override
  String toString() => "fatal: A branch named '$branchName' already exists.";
}

class GitIndexCorruptedException implements GitFatalException {
  final String reason;

  GitIndexCorruptedException(this.reason);

  @override
  String toString() => 'fatal: GitIndexCorrupted: $reason';
}
