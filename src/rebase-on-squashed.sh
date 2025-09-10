#!/usr/bin/env bash
# spellchecker: ignore Marcin Konowalczyk unmatch

# Rebases the current branch on top of a squashed version of the base branch.
# Usage: rebase-on-squashed.sh [--hard] <trunk-branch> <base-branch...>
# If --hard is provided, the files in the base branch will be kept track of,
# and any changes to those files in the current branch will be discarded.

set -euo pipefail

__VERSION__="0.1.4"
__AUTHOR__="Marcin Konowalczyk"

## LOGGING #####################################################################

RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

function _info() {
    [[ $QUIET -eq 1 ]] && return
    echo -e "${BLUE}INFO:${NC} $1"
}

function _error() {
    [[ $QUIET -eq 1 ]] && return
    echo -e "${RED}ERROR:${NC} $1" >&2
}

function _warn() {
    [[ $QUIET -eq 1 ]] && return
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

_HELP="
usage: rebase-on-squashed.sh [-h | --help] [v | --version]
       [--hard] [--trunk <trunk-branch>] [-C <path>]
       <base-branch...>

Rebases the current branch on top of a squashed version of the base branch.

Options:
  --hard                Considers the files in the base branch as authoritative.
                        Any changes to those files in the current branch will be
                        discarded.
  --trunk <branch>      Specify the trunk branch (default: main).
  -C <path>             Change to directory <path> before doing anything.
                        (default: current directory)
  -b, --branch <branch> Specify the branch to rebase. If not provided, the
                        current branch will be used.
  -q, --quiet           Suppress informational messages.
  -h, --help            Show this help message and exit.
  -v, --version         Show version information and exit.
"
function usage () {
    # remove the first and last empty lines
    echo "$_HELP" | sed '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba'
}

QUIET=0
HARD_MODE=0
TRUNK_BRANCH="main"
BASE_BRANCHES=()
BASE_BRANCH=""
CURRENT_BRANCH=""
TARGET_BRANCH=""
REPO_PATH="$PWD"

function setup() {

    function _requires_arg() {
        if [[ -z "${2:-}" ]]; then
            _error "$1 requires an argument."
            usage
            exit 1
        fi
    }

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --hard) HARD_MODE=1; shift ;;
            -h|--help)
                usage
                exit 0 ;;
            -v|--version)
                echo "rebase-on-squashed.sh version $__VERSION__"
                exit 0 ;;
            -q|--quiet) QUIET=1; shift ;;
            -C) 
                _requires_arg "-C" "$2"
                REPO_PATH="$2"; shift 2 ;;
            --trunk) 
                _requires_arg "--trunk" "$2"
                TRUNK_BRANCH="$2"; shift 2 ;;
            -b|--branch)
                _requires_arg "--branch" "$2"
                TARGET_BRANCH="$2"; shift 2 ;;
            --) shift; break ;;
            -*) _error "Unknown option: $1"; usage ;;
            *) break ;;
        esac
    done

    if [[ "$#" -lt 1 ]]; then
        usage
        exit 1
    fi

    # check if git is installed
    command -v git &> /dev/null || _fatal "Error: git is not installed."

    BASE_BRANCHES=("$@")

    # for now we support only one base branch
    [[ "${#BASE_BRANCHES[@]}" -eq 1 ]] || _fatal "Error: Only one base branch is supported for now."

    BASE_BRANCH="${BASE_BRANCHES[0]}"

    CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
}

function main () {
    if [[ ! -d "$REPO_PATH/.git" ]]; then
        _fatal "Directory $REPO_PATH is not a git repository."
    fi

    # patch git to always run in the specified directory
    if [[ "$REPO_PATH" != "$PWD" ]]; then
        _info "Operating in directory $REPO_PATH"
        function git() {
            command git -C "$REPO_PATH" "$@"
        }
    fi

    if [[ -n "$TARGET_BRANCH" ]]; then
        _info "Checking out target branch $TARGET_BRANCH"
        git checkout --quiet "$TARGET_BRANCH"
        trap 'git checkout --quiet "$CURRENT_BRANCH"' EXIT
    else
        TARGET_BRANCH="$CURRENT_BRANCH"
    fi

    if [[ "$HARD_MODE" -eq 1 ]]; then
        _info "Hard mode enabled: changes to files in the head branch will be discarded."
    fi

    _info "Target branch: $TARGET_BRANCH"
    _info "Base branch: $BASE_BRANCH"

    # stash all changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        _info "Stashing changes..."
        git stash push -u -m "rebase-on-squashed: auto-stash"
        trap 'git stash pop || true' EXIT
    fi

    # make sure the base branch has a merge base with the trunk branch
    local base_merge_base
    base_merge_base=$(git merge-base "$TRUNK_BRANCH" "$BASE_BRANCH" || true)
    if [[ -z "$base_merge_base" ]]; then
        _fatal "The base branch '$BASE_BRANCH' has no common ancestor with the trunk branch '$TRUNK_BRANCH'."
    fi
    _info "Found common ancestor between $TRUNK_BRANCH and $BASE_BRANCH: $base_merge_base"

    local current_merge_base
    current_merge_base=$(git merge-base "$TRUNK_BRANCH" "$TARGET_BRANCH" || true)
    if [[ -z "$current_merge_base" ]]; then
        _fatal "The current branch '$TARGET_BRANCH' has no common ancestor with the trunk branch '$TRUNK_BRANCH'."
    fi
    _info "Found common ancestor between $TRUNK_BRANCH and $TARGET_BRANCH: $current_merge_base"

    # check in the history of the current branch if we already have a squash commit for the base branch
    local message_head="feat(ros)!: Squashed branch '$BASE_BRANCH'"
    local message_tail="$(git rev-parse --short "$BASE_BRANCH")"

    local existing_squash_commit
    existing_squash_commit=$(git log --grep="^$message_head" --pretty=format:"%H" -1 || true)
    if [[ -n "$existing_squash_commit" ]]; then
        local existing_squash_commit_message
        existing_squash_commit_message=$(git log -1 --pretty=format:"%s" "$existing_squash_commit" || true)
        local existing_squash_commit_tail
        existing_squash_commit_tail=$(echo "$existing_squash_commit_message" | sed -E "s/.* at (.+)$/\1/" || true)
        if [[ "$existing_squash_commit_tail" == "$message_tail" ]]; then
            _info "Branch '$TARGET_BRANCH' already has a squash commit for '$BASE_BRANCH' ($existing_squash_commit). Nothing to do."
            exit 0
        fi
        _not_implemented "Rebase on existing squash commit $existing_squash_commit is not implemented yet."
    fi

    # create a new squashed version of the base branch
    local temp_branch="temp/rebase-on-squashed/${TARGET_BRANCH//\//-}-on-${BASE_BRANCH//\//-}"
    if git show-ref --verify --quiet "refs/heads/$temp_branch"; then
        _info "Deleting existing temporary branch $temp_branch"
        git branch --quiet -D "$temp_branch"
    fi

    _info "Creating temporary branch $temp_branch with squashed changes from $BASE_BRANCH"
    git checkout --quiet -b "$temp_branch" "$BASE_BRANCH"
    # shellcheck disable=SC2064
    trap "git checkout --quiet \"$TARGET_BRANCH\"; git branch --quiet -D \"$temp_branch\" || true" EXIT
    git reset --soft "$(git merge-base "$BASE_BRANCH" "$TARGET_BRANCH")"

    git commit \
        --quiet \
        --allow-empty \
        --author="$(git log -1 --pretty=format:'%an <%ae>' "$BASE_BRANCH")" \
        -m "$message_head at $message_tail"

    _info "Rebasing $TARGET_BRANCH on top of $temp_branch"
    if [[ "$HARD_MODE" -eq 1 ]]; then
        # in hard mode, we want to keep track of the files in the base branch
        # and discard any changes to those files in the current branch
        # find files which are different between the base branch and its merge base with the trunk branch
        local base_files
        base_files=$(git diff --name-only "$base_merge_base" "$BASE_BRANCH")
        base_files=$(echo "$base_files" | tr '\n' ' ')
        if [[ -z "$base_files" ]]; then
            _warn "No files changed between $base_merge_base and $BASE_BRANCH. Nothing to discard."
            git checkout --quiet "$TARGET_BRANCH"
            git rebase "$temp_branch"
            return
        fi
        _info "Files changed in $BASE_BRANCH since $base_merge_base: $base_files"
        
        # Create backup of the current branch
        local current_backup_branch="backup/rebase-on-squashed/${TARGET_BRANCH//\//-}"
        if git show-ref --verify --quiet "refs/heads/$current_backup_branch"; then
            _info "Deleting existing backup branch $current_backup_branch"
            git branch -D "$current_backup_branch"
        fi
        git checkout --quiet -b "$current_backup_branch" "$TARGET_BRANCH"

        # modify the history of the current branch (up to the merge base with the trunk branch)
        # to discard changes to the base files. If the modified commit becomes empty, discard it.
        # NOTE: we do not want to remove files from history on every commit. We just want to, 
        #       for every commit, discard any changes to the base files.
        FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch \
            --force --prune-empty \
            --index-filter '
                changed_files=$(git diff-tree --no-commit-id --name-only -r "$GIT_COMMIT")
                for file in '"$base_files"'; do
                    if echo "$changed_files" | grep -q "^$file$"; then
                        git rm --cached --ignore-unmatch "$file"
                    fi
                done
            ' \
            -- "$current_merge_base..$TARGET_BRANCH"
    fi

    git checkout --quiet "$TARGET_BRANCH"
    # rebase, but only the commits up to the merge base with the trunk branch
    local cmd="git rebase \
        --quiet \
        -X theirs \
        --onto \"$temp_branch\" \"$current_merge_base\" \"$TARGET_BRANCH\""
    _info "Running: $cmd"
    eval "$cmd"

    if [[ "$HARD_MODE" -eq 1 ]]; then
        git branch --quiet -D "$current_backup_branch" || true
    fi
}

setup "$@"
main