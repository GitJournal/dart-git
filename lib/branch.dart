import 'package:dart_git/plumbing/reference.dart';

class Branch {
  String name;
  String remote;

  ReferenceName merge; // This is a ReferenceName
}
