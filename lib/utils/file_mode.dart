import 'package:equatable/equatable.dart';

class GitFileMode extends Equatable {
  final int val;

  const GitFileMode(this.val);

  static GitFileMode parse(String str) {
    var val = int.parse(str, radix: 8);
    return GitFileMode(val);
  }

  static final Empty = GitFileMode(0);
  static final Dir = GitFileMode(int.parse('40000', radix: 8));
  static final Regular = GitFileMode(int.parse('100644', radix: 8));
  static final Deprecated = GitFileMode(int.parse('100664', radix: 8));
  static final Executable = GitFileMode(int.parse('100755', radix: 8));
  static final Symlink = GitFileMode(int.parse('120000', radix: 8));
  static final Submodule = GitFileMode(int.parse('160000', radix: 8));

  @override
  List<Object> get props => [val];

  @override
  String toString() {
    return val.toRadixString(8);
  }

  bool get isZero => val == 0;

  // FIXME: Is this written in little endian in bytes?
}
