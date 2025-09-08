
source _common.sh

function test_no_hardmode() {
  if [[ ! -d $__TEST_REPO__ ]]; then
    echo "No test repository"
    skip_if 'true' 'No test repository'
    return
  fi
  (
    cd $__TEST_REPO__ || exit 1
    git checkout branch-at-d
    rebase-on-squashed.sh branch-at-b
  )
}

# function test_hardmode() {
#   if [[ ! -d $__TEST_REPO__ ]]; then
#     echo "No test repository"
#     skip_if 'true' 'No test repository'
#     return
#   fi
#   (
#     cd $__TEST_REPO__ || exit 1
#     git checkout branch-at-e
#     rebase-on-squashed.sh --hard branch-at-b
#   )
# }
