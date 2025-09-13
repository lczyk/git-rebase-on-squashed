
source _common.sh

function test_no_hardmode() {
  if [[ ! -d "$__TEST_REPO__" ]]; then
    echo "No test repository"
    skip_if 'true' 'No test repository'
    return
  fi
  (
    cd "$__TEST_REPO__" || exit 1
    git checkout branch-at-d
    git-rebase-on-squashed branch-at-b
  )
}

function test_hardmode() {
  if [[ ! -d "$__TEST_REPO__" ]]; then
    echo "No test repository"
    skip_if 'true' 'No test repository'
    return
  fi
  (
    cd "$__TEST_REPO__" || exit 1
    git checkout branch-at-e
    git-rebase-on-squashed --hard branch-at-b
  )
}
