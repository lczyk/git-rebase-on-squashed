
source _common.sh

# functions for creating a test repo
source _test_repo.sh


function test_rebase() {
  recreate_empty_test_repo > /dev/null

  local ref_a=$(create_commit "apple")
  local ref_b=$(create_commit "banana")

  checkout_branch feature-1 "$ref_a"
  create_commit "cherry" > /dev/null

  checkout_branch feature-2 "$ref_b"
  create_commit "date" > /dev/null

  assert_equals "$(echo "
    * 358b220 (feature-1) Create cherry
    | * 367c12f (feature-2) Create date
    | * a270c96 (main) Create banana
    |/  
    * 0198d05 Create apple
    * 2bb8f03 Initial commit
  " | inline_tree | cat -A)" "$(git_tree | cat -A)"

  git-rebase-on-squashed --quiet --branch feature-2 feature-1

  local expected_tree=$(echo "
    * 358b220 (feature-1) Create cherry
    | * 3c69145 (feature-2) Create date
    | * 06a41bb feat(ros)!: Squashed branch 'feature-1' at 358b220
    |/  
    | * a270c96 (main) Create banana
    |/  
    * 0198d05 Create apple
    * 2bb8f03 Initial commit
  " | inline_tree)

  assert_equals "$expected_tree" "$(git_tree)"

  # rebase on squashed again. no changes
  git-rebase-on-squashed --quiet --branch feature-2 feature-1

  assert_equals "$expected_tree" "$(git_tree)"

  # create one more commit on feature-1
  checkout_branch feature-1
  create_commit "elderberry" > /dev/null

  assert_equals "$(echo "
    * 98ef8ca (feature-1) Create elderberry
    * 358b220 Create cherry
    | * 3c69145 (feature-2) Create date
    | * 06a41bb feat(ros)!: Squashed branch 'feature-1' at 358b220
    |/  
    | * a270c96 (main) Create banana
    |/  
    * 0198d05 Create apple
    * 2bb8f03 Initial commit
  " | inline_tree)" "$(git_tree)"

  # rebase on squashed again
  # NOT IMPLEMENTED YET
  # rebase-on-squashed --quiet --branch feature-2 feature-1

}