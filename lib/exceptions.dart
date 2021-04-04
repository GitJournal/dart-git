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
