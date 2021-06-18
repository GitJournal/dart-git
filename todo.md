We need merge support
- Creating a merge commit and resolving conflicts!

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
  - https://www.pluralsight.com/guides/understanding-and-using-git%27s-index.lock-file
  - Add `index.lock` file

Low Energy Tasks -
* Capabilities
* PktLine Decoder
* reset hard/soft
* Tests: Use a fixture instead of cloning
* GitStatusResult structure - see SimpleGit

Look at https://github.com/Byron/gitoxide and learn about community building

# Notes

simple-git has the concept of a queue so that multiple commands cannot be run in parallel.
This seems like a good idea that should also enforce?

for git-crypt support, the first step would be to implement git-attributes support
