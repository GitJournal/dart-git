import 'package:dart_git/plumbing/reference.dart';

class Branch {
  String name;
  String remote;

  ReferenceName merge;

  @override
  String toString() => 'Branch{name: $name, remote: $remote, merge: $merge}';
}
