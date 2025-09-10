[[ -z "${__TEST_REPO_SH__:-}" ]] && __TEST_REPO_SH__=1 || return 0

source _common.sh

__TEST_REPO__="$__PROJECT_ROOT__/tests/test_repo"

# set -ex
function _fatal() {
    echo "Fatal: $*" >&2
    exit 1
}

DATE="2024-01-01T00:00:00"
NAME="Test"
EMAIL="test@test.com"

# Set all the GIT_* environment variables for consistent commit hashes

function commit() {
    GIT_AUTHOR_NAME=$NAME \
    GIT_AUTHOR_EMAIL=$EMAIL \
    GIT_AUTHOR_DATE="$DATE" \
    GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" \
    GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL" \
    GIT_COMMITTER_DATE="$DATE" \
        git -C "$__TEST_REPO__" commit --quiet --allow-empty -m "$1"
}

function rebase-on-squashed() {
    GIT_AUTHOR_NAME=$NAME \
    GIT_AUTHOR_EMAIL=$EMAIL \
    GIT_AUTHOR_DATE="$DATE" \
    GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" \
    GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL" \
    GIT_COMMITTER_DATE="$DATE" \
        rebase-on-squashed.sh -C "$__TEST_REPO__" "$@"
}

function recreate_empty_test_repo() {
    if [[ -d "$__TEST_REPO__" ]]; then
        rm -rf "$__TEST_REPO__"
    fi
    mkdir -p "$__TEST_REPO__"
    git -C "$__TEST_REPO__" init --quiet -b main
    # NOTE: disable any GPG signing for test commits. This messes with the commit hashes.
    git -C "$__TEST_REPO__" config commit.gpgSign false
    commit "Initial commit"
    echo "$__TEST_REPO__"
}

function checkout_branch() {
    local branch_name="$1"
    local ref=$2
    # if ref is provided, create the branch at that ref
    if [[ -n "$ref" ]]; then
        git -C "$__TEST_REPO__" checkout --quiet -b "$branch_name" "$ref"
    else
        # just checkout the branch
        git -C "$__TEST_REPO__" checkout --quiet "$branch_name"
    fi
}

function create_commit() {
    local file_path="$1"
    local message="Create $file_path"
    touch "$__TEST_REPO__/$file_path"
    git -C "$__TEST_REPO__" add "$file_path"
    commit "$message"
    git -C "$__TEST_REPO__" rev-parse HEAD
}

# spellchecker: ignore oneline
function git_tree() {
    PAGER=cat \
        git -C "$__TEST_REPO__" log \
        --graph --oneline --all --decorate \
        | sed 's/HEAD -> //'
}

function inline_tree() {
    sed \
        -e 's/^[[:space:]]*//' \
        -e '/^$/d'
    # -e 's/[[:space:]]*$//'
}