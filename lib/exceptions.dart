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
  String toString() => "fatal: '$pathSpec' did not match any files";
}
