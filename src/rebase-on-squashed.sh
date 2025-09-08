#!/usr/bin/env bash
# spellchecker: ignore Marcin Konowalczyk unmatch

# Rebases the current branch on top of a squashed version of the target branch.
# Usage: rebase-on-squashed.sh [--hard] <trunk-branch> <target-branch...>
# If --hard is provided, the files in the target branch will be kept track of,
# and any changes to those files in the current branch will be discarded.

set -euo pipefail

__VERSION__="0.1.3"
__AUTHOR__="Marcin Konowalczyk"

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
    echo "Usage: rebase-on-squashed.sh [--hard] [--trunk <trunk-branch>] <target-branch...>"
    echo ""
    echo "Rebases the current branch on top of a squashed version of the target branch."
    echo ""
    echo "Options:"
    echo "  --hard            Discard changes to files in the target branch."
    echo "  --trunk <branch>  Specify the trunk branch (default: main)."
    echo "  -h, --help        Show this help message and exit."
    echo "  -v, --version     Show version information and exit."
}

HARD_MODE=0
TRUNK_BRANCH="main"
TARGET_BRANCHES=()
TARGET_BRANCH=""
CURRENT_BRANCH=""

_TEMP_BRANCH=""

function setup() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --hard) HARD_MODE=1; shift ;;
            -h|--help)
                usage
                exit 0 ;;
            -v|--version)
                echo "rebase-on-squashed.sh version $__VERSION__"
                exit 0 ;;
            --trunk) 
                if [[ -z "${2:-}" ]]; then
                    _error "--trunk requires an argument."
                    usage
                    exit 1
                fi
                TRUNK_BRANCH="$2"; shift 2 ;;
            --) shift; break ;;
            -*) _error "Unknown option: $1"; usage ;;
            *) break ;;
        esac
    done

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

    _info "Current branch: $CURRENT_BRANCH"
    _info "Target branch: $TARGET_BRANCH"

    # stash all changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        _info "Stashing changes..."
        git stash push -u -m "rebase-on-squashed: auto-stash"
        trap 'git stash pop || true' EXIT
    fi

    # make sure the target branch has a merge base with the trunk branch
    local target_merge_base
    target_merge_base=$(git merge-base "$TRUNK_BRANCH" "$TARGET_BRANCH" || true)
    if [[ -z "$target_merge_base" ]]; then
        _fatal "The target branch '$TARGET_BRANCH' has no common ancestor with the trunk branch '$TRUNK_BRANCH'."
    fi
    _info "Found common ancestor between $TRUNK_BRANCH and $TARGET_BRANCH: $target_merge_base"

    local current_merge_base
    current_merge_base=$(git merge-base "$TRUNK_BRANCH" "$CURRENT_BRANCH" || true)
    if [[ -z "$current_merge_base" ]]; then
        _fatal "The current branch '$CURRENT_BRANCH' has no common ancestor with the trunk branch '$TRUNK_BRANCH'."
    fi
    _info "Found common ancestor between $TRUNK_BRANCH and $CURRENT_BRANCH: $current_merge_base"

    # create a new squashed version of the target branch
    local temp_branch="temp/rebase-on-squashed/${CURRENT_BRANCH//\//-}-on-${TARGET_BRANCH//\//-}"
    if git show-ref --verify --quiet "refs/heads/$temp_branch"; then
        _info "Deleting existing temporary branch $temp_branch"
        git branch -D "$temp_branch"
    fi

    _info "Creating temporary branch $temp_branch with squashed changes from $TARGET_BRANCH"
    git checkout -b "$temp_branch" "$TARGET_BRANCH"
    # shellcheck disable=SC2064
    trap "git checkout \"$CURRENT_BRANCH\"; git branch -D \"$temp_branch\" || true" EXIT
    git reset --soft "$(git merge-base "$TARGET_BRANCH" "$CURRENT_BRANCH")"
    
    git commit \
        --allow-empty \
        --author="$(git log -1 --pretty=format:'%an <%ae>' "$TARGET_BRANCH")" \
        -m "feat!: Squashed branch $TARGET_BRANCH at $(git rev-parse --short "$TARGET_BRANCH")"

    _info "Rebasing $CURRENT_BRANCH on top of $temp_branch"
    if [[ "$HARD_MODE" -eq 1 ]]; then
        # in hard mode, we want to keep track of the files in the target branch
        # and discard any changes to those files in the current branch
        # find files which are different between the target branch and its merge base with the trunk branch
        local target_files
        target_files=$(git diff --name-only "$target_merge_base" "$TARGET_BRANCH")
        target_files=$(echo "$target_files" | tr '\n' ' ')
        if [[ -z "$target_files" ]]; then
            _warn "No files changed between $target_merge_base and $TARGET_BRANCH. Nothing to discard."
            git checkout "$CURRENT_BRANCH"
            git rebase "$temp_branch"
            return
        fi
        _info "Files changed in $TARGET_BRANCH since $target_merge_base: $target_files"
        
        # Create backup of the current branch
        local current_backup_branch="backup/rebase-on-squashed/${CURRENT_BRANCH//\//-}"
        if git show-ref --verify --quiet "refs/heads/$current_backup_branch"; then
            _info "Deleting existing backup branch $current_backup_branch"
            git branch -D "$current_backup_branch"
        fi
        git checkout -b "$current_backup_branch" "$CURRENT_BRANCH"

        # modify the history of the current branch (up to the merge base with the trunk branch)
        # to discard changes to the target files. If the modified commit becomes empty, discard it.
        # NOTE: we do not want to remove files from history on every commit. We just want to, 
        #       for every commit, discard any changes to the target files.
        FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch \
            --force --prune-empty \
            --index-filter '
                changed_files=$(git diff-tree --no-commit-id --name-only -r "$GIT_COMMIT")
                for file in '"$target_files"'; do
                    if echo "$changed_files" | grep -q "^$file$"; then
                        git rm --cached --ignore-unmatch "$file"
                    fi
                done
            ' \
            -- "$current_merge_base..$CURRENT_BRANCH"
    fi

    git checkout "$CURRENT_BRANCH"
    # rebase, but only the commits up to the merge base with the trunk branch
    local cmd="git rebase \
        -X theirs \
        --onto \"$temp_branch\" \"$current_merge_base\" \"$CURRENT_BRANCH\""
    _info "Running: $cmd"
    eval "$cmd"

    if [[ "$HARD_MODE" -eq 1 ]]; then
        git branch -D "$current_backup_branch" || true
    fi
}

setup "$@"
main