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
* Move expensive code to another isolate
* Do not allow concurrent modifications to the isolate

* Modifying the index - What if someone else has modified it during that time?
  - https://www.pluralsight.com/guides/understanding-and-using-git%27s-index.lock-file
  - Add `index.lock` file

Low Energy Tasks -
* Capabilities
* PktLine Decoder
* git clean
* reset hard/soft - Hard test when there are modifications or some extra files.
* Tests: Use a fixture instead of cloning
* GitStatusResult structure - see SimpleGit

Look at https://github.com/Byron/gitoxide and learn about community building

# Notes

simple-git has the concept of a queue so that multiple commands cannot be run in parallel.
This seems like a good idea that should also enforce?

# Encryption

For git-crypt support, the first step would be to implement git-attributes support. Take a look at go-git's implementation.

I don't believe it makes sense to implement git-crypt support. Only because it's so fucking complex, and transfering the key is not simple. Plus, use git-crypt requires understanding gpg to a certain extent that it's not practical.

Age encryption is much much easier, and there is agebox but that doesn't integrate with git and doesn't encrypt to a plain text version. Though I'm not sure why that is a big issue. It seems like creating a tool like agebox which integrates with git is the best option. All that would be needed is support for modifying the git attributes and clean/smudge/diff support.

Maybe git-crypt with just the password. I can't imagine supporting all of pgp stuff. I can transfer the key via a QR code.
-> cat key | base64 | qrencode -t ansiutf8
