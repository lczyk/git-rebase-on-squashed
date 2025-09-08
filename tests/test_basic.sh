
source _common.sh

function test_help() {
  local out
  out=$(rebase-on-squashed.sh -h 2>&1)
  assert_equals 0 $?
  assert_contains "usage: rebase-on-squashed.sh" "$out"
}

function test_version() {
  local out
  out=$(rebase-on-squashed.sh -v 2>&1)
  assert_equals 0 $?
  assert_contains "rebase-on-squashed.sh version" "$out"
}