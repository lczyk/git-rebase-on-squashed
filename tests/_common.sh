[[ -z "${__COMMON_SH__:-}" ]] && __COMMON_SH__=1 || return 0

__PROJECT_ROOT__="$(dirname "$PWD")"
# add src to PATH
export PATH="$__PROJECT_ROOT__/src:$PATH"

__TEST_REPO__="$__PROJECT_ROOT__/tests/test_repo"

function assert_contains() {
    local expected="$1"
    local actual="$2"
    if [[ "$actual" != *"$expected"* ]]; then
        echo "Assertion failed: expected output to contain '$expected', but got '$actual'"
        exit 1
    fi
}