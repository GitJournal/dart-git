import 'package:dart_git/git_hash.dart';

enum ReferenceType {
  Hash,
  Symbolic,
}

class Reference {
  ReferenceType type;
  ReferenceName name;
  GitHash hash;
  ReferenceName target;

  Reference(String source, String target) {
    name = ReferenceName(source);
    if (target.startsWith(symbolicRefPrefix)) {
      this.target = ReferenceName(target.substring(symbolicRefPrefix.length));
      type = ReferenceType.Symbolic;
      return;
    }

    hash = GitHash(target);
    type = ReferenceType.Hash;
  }

  String toDisplayString() {
    switch (type) {
      case ReferenceType.Hash:
        return '$name $hash';
      case ReferenceType.Symbolic:
        return '$name $symbolicRefPrefix$target';
      default:
        assert(false, 'Reference has an invalid type');
    }
    return '';
  }

  bool get isSymbolic => type == ReferenceType.Symbolic;
  bool get isHash => type == ReferenceType.Hash;

  @override
  String toString() => isSymbolic ? '$name -> $target' : '$name -> sha1($hash)';
}

const refPrefix = 'refs/';
const refHeadPrefix = refPrefix + 'heads/';
const refTagPrefix = refPrefix + 'tags/';
const refRemotePrefix = refPrefix + 'remotes/';
const refNotePrefix = refPrefix + 'notes/';
const symbolicRefPrefix = 'ref: ';

class ReferenceName {
  String value;
  ReferenceName(this.value);

  ReferenceName.remote(String remote, String branch) {
    value = '$refRemotePrefix$remote/$branch';
  }

  @override
  String toString() => value;

  bool isBranch() => value.startsWith(refHeadPrefix);
  bool isTag() => value.startsWith(refTagPrefix);
  bool isRemote() => value.startsWith(refRemotePrefix);
  bool isNote() => value.startsWith(refNotePrefix);

  String branchName() {
    assert(isBranch());
    return value.substring(refHeadPrefix.length);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ReferenceName && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
