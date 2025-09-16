# git-rebase-on-squashed

[![bash_unit tests](https://github.com/lczyk/rebase-on-squashed/actions/workflows/test.yaml/badge.svg)](https://github.com/lczyk/rebase-on-squashed/actions/workflows/test.yaml)

Rebase a branch on top of a squashed version of another one.

NOTE: This tool might have a couple of sharp edges! Do not use if you are not
comfortable with normal git rebasing, and potentially fixing any problems which
may arise. Always back up your branches!

## about

Lets consider a tree with two feature branches:

```
...
| * 97f9c73 (B) feat: different feature which depends on the spice
|/ 
* 64da366 fix: something
* b63f680 feat: something
|
| * b5007af (A) feat: even more spice
| * ddf46d9 feat: my spicy feature
|/  
* 32c24f0 chore: update some version
* 3444ce5 feat: do something
...
```

Feature branch B wants all the changes from feature branch `A`, but branch `A`
is not merged into the "trunk" branch (usually main). We can just rebase `B`
on top of `A`, but then as `A` may grow in number of commits, it becomes cumbersome,
especially if there is a chain of these kind of rebases.

Instead, we can squash all the commits we're rebasing on top of into one
convenient commit. This is what this tool does. If we run:

```bash
git rebase-on-squashed --trunk main --branch B A
```

(or, since `main` is the default, and if we have `B` checked out, just
`git rebase-on-squashed A`)

we get:

```
...
| * 7b285e2 (B) feat: different feature which depends on the spice
| * 4cc6d7e feat(ros)!: Squashed branch 'A' at b5007af
|/ 
* 64da366 fix: something
* b63f680 feat: something
|
| * b5007af (A) feat: even more spice
| * ddf46d9 feat: my spicy feature
|/  
* 32c24f0 chore: update some version
* 3444ce5 feat: do something
...
```

## hardmode

Given the example above, hardmode (enabled with the `--hard` flag), is actually
quite simple to explain. Lets imagine that i *know* that `B` does not touch any
of the same files as `A` -- `B` depends on the existence of these files, but
does not modify them. hardmode goes through all the commits of B and does any
appropriate history rewrites to remove any changes that `B` might make to any of
the files in `A`. Useful if you've already made a bunch of commits on `B` which
touch `A`'s files, but now you want to filter them out.

NOTE: This uses the [infamous](https://git-scm.com/docs/git-filter-branch#_warning) `git filter-branch`
command. Be warned and *especially* don't use this option if you don't know what
you're doing / how to fix rebases / how to recover lost branches from reflog. Also
have remote backups. Don't be afraid of git, but always respect the git.

## todos/ideas

- [x] more readable test repo
- [ ] test remote target
- [ ] test target in unrelated history
- [ ] ? multiple rebases
- [x] `--tree`
- [ ] `--tree` but scan better, not just in a line
- [ ] probably should port to python kindof like [git-filter-repo](https://github.com/newren/git-filter-repo)
- [ ] ? way of viewing the diff sans the squashed rebase 