# git-rebase-on-squashed
Script to rebase a bunch of stuff on top of a squashed state of another branch

```
* 49f9f70 (HEAD -> branch-at-e) Modify b1 in branch-at-e
* 5bb259c Create e2
* cf4504f Create e1
| * 7b51399 (branch-at-d) Create d2
| * fcefdd4 Create d1
| | * 75898a3 (branch-at-b) Create b2
| | * e5ef21f Create b1
| | | * f9047e5 (main) Create f
| |_|/  
|/| |   
* | | 2ba098a Create e
|/ /  
* | 8bea592 Create d
* | ddf46d9 Create c
|/  
* 32c24f0 Create b
* 3444ce5 Create a
* f28c115 Initial commit
```

after rebasing `branch-at-d` on top of `branch-at-b`,
and also `branch-at-e` on top of `branch-at-b` with `--hard` flag:

```
* 7b285e2 (HEAD -> branch-at-d) Create d2
* 97f9c73 Create d1
* 4cc6d7e Squashed changes from branch-at-b
| * b63f680 (branch-at-e) Create e2
| * 64da366 Create e1
| * 0d45941 Squashed changes from branch-at-b
|/  
| * 79c677c Modify b1 in branch-at-e
| * b5007af Create e2
| * 481bc72 Create e1
| | * e0608ad (branch-at-b) Create b2
| | * 60ab6d0 Create b1
| |/  
|/|   
| | * e14bc27 (main) Create f
| |/  
| * 849699b Create e
| * 542fd1c Create d
| * 8813fdc Create c
|/  
* ec8ff27 Create b
* c1e2f9d Create a
* 02e2ee8 Initial commit
```


## todos

- [ ] more readable test repo
- [ ] test remote target
- [ ] test target in unrelated history
- [ ] Multiple rebases