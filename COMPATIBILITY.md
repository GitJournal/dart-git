Supported Capabilities
======================

Here is a non-comprehensive table of git commands and features whose equivalent
is supported by dart-git.

| Feature                               | Status | Notes |
|---------------------------------------|--------|-------|
| **config**                            |
| config                                | ✔ | Reading and modifying per-repository configuration (`.git/config`) is supported. Global configuration (`$HOME/.gitconfig`) is not. |
| **getting and creating repositories** |
| init                                  | ✔ | Plain init is supported. Flags `--bare` `--template`, `--separate-git-dir` and `--shared` are not. |
| clone                                 | ✖ |
| **basic snapshotting** |
| add                                   | ✔ | Plain add is supported. Any other flags aren't supported |
| status                                | ✖ |
| commit                                | ✔ |
| reset                                 | ✔ |
| rm                                    | ✔ |
| mv                                    | ✖ |
| **branching and merging** |
| branch                                | ✔ |
| checkout                              | ✔ | Basic usages of checkout are supported. |
| merge                                 | ✖ |
| mergetool                             | ✖ |
| stash                                 | ✖ |
| tag                                   | ✖ |
| **sharing and updating projects** |
| fetch                                 | ✖ |
| pull                                  | ✖ |
| push                                  | ✖ |
| remote                                | ✖ |
| submodule                             | ✖ |
| **inspection and comparison** |
| show                                  | ✔ |
| log                                   | ✔ |
| shortlog                              | (see log) |
| describe                              | |
| **patching** |
| apply                                 | ✖ |
| cherry-pick                           | ✖ |
| diff                                  | ✖ |
| rebase                                | ✖ |
| revert                                | ✖ |
| **debugging** |
| bisect                                | ✖ |
| blame                                 | ✖ |
| grep                                  | ✖ |
| **email** ||
| am                                    | ✖ |
| apply                                 | ✖ |
| format-patch                          | ✖ |
| send-email                            | ✖ |
| request-pull                          | ✖ |
| **external systems** |
| svn                                   | ✖ |
| fast-import                           | ✖ |
| **administration** |
| clean                                 | ✖ |
| gc                                    | ✖ |
| fsck                                  | ✖ |
| reflog                                | ✖ |
| filter-branch                         | ✖ |
| instaweb                              | ✖ |
| archive                               | ✖ |
| bundle                                | ✖ |
| prune                                 | ✖ |
| repack                                | ✖ |
| **server admin** |
| daemon                                | |
| update-server-info                    | |
| **advanced** |
| notes                                 | ✖ |
| replace                               | ✖ |
| worktree                              | ✖ |
| annotate                              | (see blame) |
| **gpg** |
| git-verify-commit                     | ✖ |
| git-verify-tag                        | ✖ |
| **plumbing commands** |
| cat-file                              | ✔ |
| check-ignore                          | ✖ |
| commit-tree                           | ✖ |
| count-objects                         | ✖ |
| diff-index                            | ✖ |
| for-each-ref                          | ✖ |
| hash-object                           | ✔ |
| ls-files                              | ✖ |
| ls-tree                               | ✔ |
| merge-base                            | ✔ | Calculates the merge-base only between two commits. Supports `--independent` and `--is-ancestor` modifiers; Does not support `--fork-point` nor `--octopus` modifiers. |
| read-tree                             | ✖ |
| rev-list                              | ✖ |
| rev-parse                             | ✖ |
| show-ref                              | ✖ |
| symbolic-ref                          | ✖ |
| update-index                          | ✖ |
| update-ref                            | ✖ |
| verify-pack                           | ✖ |
| write-tree                            | ✔ |
| **protocols** |
| http(s):// (dumb)                     | ✖ |
| http(s):// (smart)                    | ✖ |
| git://                                | ✖ |
| ssh://                                | ✖ |
| file://                               | ✖ |
| custom                                | ✖ |
| **other features** |
| gitignore                             | ✖ |
| gitattributes                         | ✖ |
| index version                         | 2 - 4 |
| packfile version                      | 2 |
| push-certs                            | ✖ |
