We need merge support
- Simple fast forwards
- Creating a merge commit and resolving conflicts!

For Diffs we could use -
  * Word based: https://pub.dev/packages/diff_match_patch
  * Classical: https://pub.dev/packages/diff2

* Revision Support - At some point we might need support for stuff like HEAD^
  https://mirrors.edge.kernel.org/pub/software/scm/git/docs/gitrevisions.html

  This is medium level task, that requires almost no knowledge about git
  Take a look at how go-git does it.

- Integrate date time tz
- Implement delta figuring out
- Clean up ObjectStorage (remove function to get an object from a path)
- Clean up Packfile tests
- Clean up Indexes tests

- Create
  - WorkTree
    - All fs operations go here

Important -
* saving a ref should be updating a ref, and doing that can fail
  if some other process if attempting to modify it. We need this
  operation to be atomic.
  - Can throw LockFailure

* Modifying the index - What if someone else has modified it during that time?