#!/bin/bash

# Create a test repository for the availability matrix project.

set -euo pipefail

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    echo "This script must be run directly, not sourced."
    exit 1
fi

__THIS_FILE_DIR__=$(dirname "$(readlink -f "$0")")
__PROJECT_ROOT__=$(realpath "$__THIS_FILE_DIR__/..")

# echo "__THIS_FILE_DIR__ = $__THIS_FILE_DIR__"
# echo "__PROJECT_ROOT__ = $__PROJECT_ROOT__"

TEST_REPO_DIR="$__PROJECT_ROOT__/tests/test_repo"
if [[ -d "$TEST_REPO_DIR" ]]; then
    echo "Test repository already exists at $TEST_REPO_DIR. Please remove it before running this script."
    exit 1
fi

GIT_QUIET="--quiet"

function create() {
    local file_path="$1"
    local message="${2:-"Create $file_path"}"
    touch "$file_path"
    git add "$file_path"
    git commit $GIT_QUIET -m "$message"
    git rev-parse HEAD
}

function main() {
    echo "Creating test repository at $TEST_REPO_DIR"
    mkdir -p "$TEST_REPO_DIR"
    (
        cd "$TEST_REPO_DIR"
        git init $GIT_QUIET -b main
        git commit $GIT_QUIET --allow-empty -m "Initial commit"

        local ref_a=$(create a)
        local ref_b=$(create b)
        local ref_c=$(create c)
        local ref_d=$(create d)
        local ref_e=$(create e)
        local ref_f=$(create f)

        # Create a branch at B called "branch-at-b"
        git checkout $GIT_QUIET -b branch-at-b "$ref_b"
        create b1 > /dev/null
        create b2 > /dev/null

        # Create a branch at D called "branch-at-d"
        git checkout $GIT_QUIET -b branch-at-d "$ref_d"
        create d1 > /dev/null
        create d2 > /dev/null

        # Create a branch at E called "branch-at-e"
        git checkout $GIT_QUIET -b branch-at-e "$ref_e"
        create e1 > /dev/null
        create e2 > /dev/null

        # branch-at-E will also touch b1
        create b1 "Modify b1 in branch-at-e" > /dev/null

        echo "Test repository created. Here is the commit graph:"
        PAGER=cat git log --graph --oneline --all --decorate
    )
}

main "$@"