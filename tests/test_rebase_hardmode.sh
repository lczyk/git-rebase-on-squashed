
source _common.sh

# functions for creating a test repo
source _test_repo.sh


function test_rebase_hard() {
  recreate_empty_test_repo > /dev/null

  local ref_a=$(create_commit "apple")
  local ref_b=$(create_commit "banana")

  checkout_branch feature-1 "$ref_a"
  create_commit "cherry" > /dev/null

  checkout_branch feature-2 "$ref_a"
  create_commit "date" > /dev/null
  create_commit "cherry" > /dev/null
  create_commit "elderberry" > /dev/null

  assert_equals "$(echo "
    * 358b220 (feature-1) Create cherry
    | * c118648 (feature-2) Create elderberry
    | * df05022 Create cherry
    | * 15f3196 Create date
    |/  
    | * a270c96 (main) Create banana
    |/  
    * 0198d05 Create apple
    * 2bb8f03 Initial commit
  " | inline_tree)" "$(git_tree)"

  git-rebase-on-squashed --hard --quiet --branch feature-2 feature-1

  assert_equals "$(echo "
    * 358b220 (feature-1) Create cherry
    | * 1940f3f (feature-2) Create elderberry
    | * 3c69145 Create date
    | * 06a41bb feat(ros)!: Squashed branch 'feature-1' at 358b220
    |/  
    | * a270c96 (main) Create banana
    |/  
    * 0198d05 Create apple
    * 2bb8f03 Initial commit
  " | inline_tree)" "$(git_tree)"
}