
source _common.sh

function test_help() {
  local out
  out=$(git-rebase-on-squashed -h 2>&1)
  assert_equals 0 $?
  assert_contains "usage: git-rebase-on-squashed" "$out"
}

function test_version() {
  local out
  out=$(git-rebase-on-squashed -v 2>&1)
  assert_equals 0 $?
  assert_contains "git-rebase-on-squashed version" "$out"
}