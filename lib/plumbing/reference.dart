// Reference class
// contains

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

  // Constructor for Symbolic
  // Constructor for Hash

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

// Implement ==
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

/*

type Reference struct {
	t      ReferenceType
	n      ReferenceName
	h      Hash
	target ReferenceName
}

// Have a method to shorten it

We also have a ReferenceStorage class
- a way to convert looose refs to packed ones

Implement this for the FS -
- you can easily lookup how

For fetching the remote branch name -
- we would look at /ref/remotes/origin/HEAD to see the default branch
  ( gives a ref - repo.remote("origin").head()
  ( make sure it is symbolic and get the branch )
  -> Need a way to convert a ref into remoteName and branchName

For checking if there are any commits to push
  -> Get oid .git/HEAD
  -> Get current branch from .git/HEAD
  -> Get tracking branch from .git/config
  -> Get that branch's oid

   -> repo.head() -> repo.resolveReference(ref) -> hash
   -> repo.branch(...) -> BranchConfig
   -> BranchConfig gives remote and refspec of tracking branch
   -> construct ref out of that info, and use resolveReference()
-> Maybe 2 hours.

Commands to implement -
* git branch (--list which is the default)
* git branch NAME --set-upstream-to=

The GitRepository class gets a -
* head() method
* reference(string refName, bool resolve)

Expose the storage via Repository.storage
-> storage.SetReference()
-> storage.RemoveReference()

Not sure if these should take a string or a separate object
Ideally a typedef would be perfect, but we need to wait for that.

How would I fetch the ref for the remote?
- A Remote Object which contains what?
  -> Storage (all types)
  -> RemoteConfig (from .git/config)
  -> head function

Can re-implement the `git remote` command
*/
