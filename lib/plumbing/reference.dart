import 'package:dart_git/plumbing/git_hash.dart';
import 'package:meta/meta.dart';

enum ReferenceType {
  Hash,
  Symbolic,
}

@immutable
sealed class Reference {
  ReferenceName get name;

  String serialize();
  String toDisplayString();

  static Reference build(String source, String target) {
    if (source.isEmpty) throw ArgumentError('source is empty');
    if (target.isEmpty) throw ArgumentError('target is empty');

    var name = ReferenceName(source);
    if (target.startsWith(symbolicRefPrefix)) {
      var targetRef = ReferenceName(target.substring(symbolicRefPrefix.length));
      return SymbolicReference(name, targetRef);
    }

    return HashReference(name, GitHash(target));
  }
}

@immutable
class HashReference extends Reference {
  @override
  final ReferenceName name;
  final GitHash hash;

  HashReference(this.name, this.hash);
  HashReference.empty(this.name) : hash = GitHash.zero();

  @override
  String toString() => '$name -> sha1($hash)';

  @override
  String serialize() => '$hash\n';

  @override
  String toDisplayString() => '$name $hash';
}

class SymbolicReference extends Reference {
  @override
  final ReferenceName name;
  final ReferenceName target;

  SymbolicReference(this.name, this.target);

  @override
  String toString() => '$name -> $target';

  @override
  String serialize() => '$symbolicRefPrefix${target.value}\n';

  @override
  String toDisplayString() => '$name $symbolicRefPrefix$target';
}

const refHead = 'HEAD';
const refPrefix = 'refs/';
const refHeadPrefix = '${refPrefix}heads/';
const refTagPrefix = '${refPrefix}tags/';
const refRemotePrefix = '${refPrefix}remotes/';
const refNotePrefix = '${refPrefix}notes/';
const symbolicRefPrefix = 'ref: ';

class ReferenceName {
  late String value;
  ReferenceName(this.value) {
    assert(value.startsWith(refPrefix) || value == refHead, 'prefix: $value');
  }

  ReferenceName.remote(String remote, String branch) {
    value = '$refRemotePrefix$remote/$branch';
  }
  ReferenceName.branch(String branch) {
    value = '$refHeadPrefix$branch';
  }

  static ReferenceName HEAD() => ReferenceName(refHead);

  @override
  String toString() => value;

  bool isBranch() => value.startsWith(refHeadPrefix);
  bool isTag() => value.startsWith(refTagPrefix);
  bool isRemote() => value.startsWith(refRemotePrefix);
  bool isNote() => value.startsWith(refNotePrefix);

  // is null when isTag or isNote
  String? branchName() {
    assert(isBranch() || isRemote());
    if (isBranch()) {
      return value.substring(refHeadPrefix.length);
    } else if (isRemote()) {
      return value
          .substring(refRemotePrefix.length)
          .split('/')
          .sublist(1)
          .join('/');
    }

    return null;
  }

  String remoteName() {
    assert(isRemote());
    return value.substring(refRemotePrefix.length).split('/').first;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ReferenceName && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
