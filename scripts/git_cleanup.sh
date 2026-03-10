#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# git_cleanup.sh
# Delete local Git branches that have already been merged into the default
# branch. Handles simple merges, squash merges, and rebase merges.
# Never deletes the current branch or the default branch.
#
# Prerequisites:
#   - git: must be installed and on PATH
#
# Usage:
#   ./git_cleanup.sh [OPTIONS]
#   ./git_cleanup.sh --help
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"

# ---------------------------------------------------------------------------
# Output Helpers
# ---------------------------------------------------------------------------

readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

usage() {
  local exit_code="${1:-0}"
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Delete local Git branches that have already been merged into the default
branch. Detects simple merges, squash merges, and rebase merges.

The current branch and the default branch are never deleted.

Options:
  -h, --help          Show this help message and exit
  -v, --verbose       Enable verbose output
  -d, --dry-run       Show branches that would be deleted without deleting them
  --version           Show version and exit

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --dry-run
  ${SCRIPT_NAME} --verbose

EOF
  exit "${exit_code}"
}

# ---------------------------------------------------------------------------
# Argument Parsing
# ---------------------------------------------------------------------------

VERBOSE=false
DRY_RUN=false

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage 0
        ;;
      --version)
        echo "${SCRIPT_NAME} version ${SCRIPT_VERSION}"
        exit 0
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      -d|--dry-run)
        DRY_RUN=true
        shift
        ;;
      -*)
        error "Unknown option: $1"
        usage 1
        ;;
      *)
        error "Unexpected argument: $1"
        usage 1
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Dependency Check
# ---------------------------------------------------------------------------

check_dependencies() {
  if ! command -v git &>/dev/null; then
    error "git is not installed or not on PATH."
    error "Install git: https://git-scm.com/downloads"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Resolve the default branch (main, master, or whatever the remote HEAD points to).
get_default_branch() {
  local default_branch

  # Prefer the remote HEAD symbolic ref (works after a fresh clone or fetch).
  if git rev-parse --verify --quiet refs/remotes/origin/HEAD &>/dev/null; then
    default_branch="$(git rev-parse --abbrev-ref refs/remotes/origin/HEAD)"
    default_branch="${default_branch#origin/}"
    echo "${default_branch}"
    return
  fi

  # Fall back to checking common names.
  for candidate in main master develop; do
    if git rev-parse --verify --quiet "refs/heads/${candidate}" &>/dev/null; then
      echo "${candidate}"
      return
    fi
  done

  error "Could not determine the default branch."
  error "Ensure you are inside a Git repository and have fetched from the remote."
  exit 1
}

# Return 0 if the branch was merged via a simple merge (commit appears in default branch log).
is_simple_merged() {
  local branch="$1"
  local default_branch="$2"
  git merge-base --is-ancestor "${branch}" "${default_branch}" 2>/dev/null
}

# Return 0 if the branch was merged via squash (tree of tip matches a commit in default branch).
is_squash_merged() {
  local branch="$1"
  local default_branch="$2"
  local merge_base tree_branch

  merge_base="$(git merge-base "${default_branch}" "${branch}" 2>/dev/null)" || return 1
  tree_branch="$(git rev-parse "${branch}^{tree}" 2>/dev/null)"              || return 1

  # Walk commits on the default branch since the merge-base and look for a
  # commit whose tree matches the branch tip tree (characteristic of a squash).
  git log --pretty=format:"%T %H" "${merge_base}..${default_branch}" 2>/dev/null \
    | while IFS=' ' read -r tree _commit; do
        if [[ "${tree}" == "${tree_branch}" ]]; then
          exit 0   # found — signal success via subshell exit code
        fi
      done
  return $?
}

# Return 0 if the branch was merged via rebase (all branch commits are reachable
# from the default branch, matched by patch-id).
is_rebase_merged() {
  local branch="$1"
  local default_branch="$2"
  local merge_base branch_patch_ids default_patch_ids branch_commit_count matched

  merge_base="$(git merge-base "${default_branch}" "${branch}" 2>/dev/null)" || return 1

  # Collect patch-ids for commits on the branch that are not already on the default branch.
  branch_patch_ids="$(
    git log --pretty=format:"%H" "${merge_base}..${branch}" 2>/dev/null \
      | git diff-tree --stdin -p 2>/dev/null \
      | git patch-id --stable 2>/dev/null \
      | awk '{print $1}'
  )"

  [[ -z "${branch_patch_ids}" ]] && return 1   # no unique commits → not a rebase candidate

  branch_commit_count="$(echo "${branch_patch_ids}" | wc -l | tr -d ' ')"

  # Collect patch-ids for commits on the default branch that are not in the branch.
  default_patch_ids="$(
    git log --pretty=format:"%H" "${merge_base}..${default_branch}" 2>/dev/null \
      | git diff-tree --stdin -p 2>/dev/null \
      | git patch-id --stable 2>/dev/null \
      | awk '{print $1}'
  )"

  [[ -z "${default_patch_ids}" ]] && return 1

  # Count how many branch patch-ids appear in the default branch patch-ids.
  matched=0
  while IFS= read -r pid; do
    if echo "${default_patch_ids}" | grep -qF "${pid}"; then
      matched=$(( matched + 1 ))
    fi
  done <<< "${branch_patch_ids}"

  # All branch commits must be matched.
  [[ "${matched}" -eq "${branch_commit_count}" ]]
}

# ---------------------------------------------------------------------------
# Core Logic
# ---------------------------------------------------------------------------

cleanup_branches() {
  local current_branch default_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD)"
  default_branch="$(get_default_branch)"

  info "Current branch  : ${current_branch}"
  info "Default branch  : ${default_branch}"
  [[ "${DRY_RUN}" == true ]] && warn "Dry-run mode — no branches will be deleted."
  echo ""

  local deleted=0
  local skipped=0

  while IFS= read -r branch; do
    # Strip leading whitespace that git branch output may include.
    branch="${branch#"${branch%%[![:space:]]*}"}"

    # Never touch the current or default branch.
    if [[ "${branch}" == "${current_branch}" || "${branch}" == "${default_branch}" ]]; then
      [[ "${VERBOSE}" == true ]] && info "Skipping protected branch: ${branch}"
      (( skipped++ )) || true
      continue
    fi

    local reason=""

    if is_simple_merged "${branch}" "${default_branch}"; then
      reason="simple merge"
    elif is_squash_merged "${branch}" "${default_branch}"; then
      reason="squash merge"
    elif is_rebase_merged "${branch}" "${default_branch}"; then
      reason="rebase merge"
    fi

    if [[ -n "${reason}" ]]; then
      if [[ "${DRY_RUN}" == true ]]; then
        warn "Would delete: ${branch}  (${reason})"
      else
        if git branch -D "${branch}" &>/dev/null; then
          success "Deleted: ${branch}  (${reason})"
          (( deleted++ )) || true
        else
          error "Failed to delete: ${branch}"
        fi
      fi
    else
      [[ "${VERBOSE}" == true ]] && info "Keeping: ${branch}  (not fully merged)"
      (( skipped++ )) || true
    fi

  done < <(git branch --format='%(refname:short)' 2>/dev/null)

  echo ""
  if [[ "${DRY_RUN}" == true ]]; then
    info "Dry run complete. Run without --dry-run to apply changes."
  else
    success "Done. Branches deleted: ${deleted} | Branches kept: ${skipped}"
  fi
}

# ---------------------------------------------------------------------------
# Entry Point
# ---------------------------------------------------------------------------

main() {
  parse_args "$@"
  check_dependencies

  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    error "Not inside a Git repository."
    exit 1
  fi

  cleanup_branches
}

main "$@"

