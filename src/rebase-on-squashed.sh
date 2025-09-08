#!/usr/bin/env bash

# Rebases the current branch on top of a squashed version of the target branch.
# Usage: rebase-on-squashed.sh [--hard] <target-branch...>
# If --hard is provided, the files in the target branch will be kept track of,
# and any changes to those files in the current branch will be discarded.

set -euo pipefail

__VERSION__="0.1.0"

## LOGGING #####################################################################

RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

function _info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

function _error() {
    echo -e "${RED}ERROR:${NC} $1" >&2
}

function _warn() {
    echo -e "${YELLOW}WARNING:${NC} $1" >&2
}

function _fatal() {
    _error "$1"; exit 1;
}

function _not_implemented() {
    echo -e "${RED}NOT IMPLEMENTED:${NC} $1" >&2
    exit 2
}

################################################################################

function usage () {
    echo "Usage: rebase-on-squashed.sh [--hard] <target-branch...>"
    echo ""
    echo "Rebases the current branch on top of a squashed version of the target branch."
    echo ""
    echo "Options:"
    echo "  --hard          Discard changes to files in the target branch."
    echo "  -h, --help     Show this help message and exit."
    echo "  -v, --version  Show version information and exit."
}

HARD_MODE=0
TARGET_BRANCHES=()
TARGET_BRANCH=""
CURRENT_BRANCH=""

_TEMP_BRANCH=""

function setup () {

    HARD_MODE=0
    HELP=0
    VERSION=0
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --hard) HARD_MODE=1; shift ;;
            -h|--help) HELP=1; shift ;;
            -v|--version) VERSION=1; shift ;;
            --) shift; break ;;
            -*) _error "Unknown option: $1"; usage ;;
            *) break ;;
        esac
    done

    if [[ "$HELP" -eq 1 ]]; then
        usage
        exit 0
    fi

    if [[ "$VERSION" -eq 1 ]]; then
        echo "rebase-on-squashed.sh version $__VERSION__"
        exit 0
    fi

    if [[ "$#" -lt 1 ]]; then
        usage
        exit 1
    fi

    if ! command -v git &> /dev/null; then
        echo "Error: git is not installed."
        exit 1
    fi

    TARGET_BRANCHES=("$@")

    # for now we support only one target branch
    if [[ "${#TARGET_BRANCHES[@]}" -ne 1 ]]; then
        echo "Error: Only one target branch is supported for now."
        exit 1
    fi

    TARGET_BRANCH="${TARGET_BRANCHES[0]}"

    CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
}

function main () {
    if [[ "$HARD_MODE" -eq 1 ]]; then
        _info "Hard mode enabled: changes to files in the target branch will be discarded."
    fi

    # stash all changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        _info "Stashing changes..."
        git stash push -u -m "rebase-on-squashed: auto-stash"
        trap 'git stash pop || true' EXIT
    fi

    # create a new squashed version of the target branch
    local temp_branch="temp/rebase-on-squashed/${CURRENT_BRANCH//\//-}-on-${TARGET_BRANCH//\//-}"
    if git show-ref --verify --quiet "refs/heads/$temp_branch"; then
        _info "Deleting existing temporary branch $temp_branch"
        git branch -D "$temp_branch"
    fi

    _info "Creating temporary branch $temp_branch with squashed changes from $TARGET_BRANCH"
    git checkout -b "$temp_branch" "$TARGET_BRANCH"
    trap "git checkout \"$CURRENT_BRANCH\"; git branch -D \"$temp_branch\" || true" EXIT
    git reset --soft "$(git merge-base "$TARGET_BRANCH" "$CURRENT_BRANCH")"
    git commit -m "Squashed changes from $TARGET_BRANCH"=

    _info "Rebasing $CURRENT_BRANCH on top of $temp_branch"
    if [[ "$HARD_MODE" -eq 1 ]]; then
        # in hard mode, we want to keep track of the files in the target branch
        # and discard any changes to those files in the current branch
        _not_implemented "Hard mode is not implemented yet."    else
        git checkout "$CURRENT_BRANCH"
        git rebase "$temp_branch"
    else
        git checkout "$CURRENT_BRANCH"
        git rebase "$temp_branch"
    fi
}

setup "$@"
main