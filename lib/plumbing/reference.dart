// Reference class
// contains

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
