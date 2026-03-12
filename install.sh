#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# install.sh
# Install dev-pack scripts, skills, agents, and templates onto a developer
# machine by creating managed symlinks to the appropriate locations.
#
# Prerequisites:
#   - git: required for clone and update operations
#   - DEV_HOME: path to developer home directory
#   - CODE_HOME: path to code directory (repo will be cloned here)
#   - SCRIPTS_HOME: path where script symlinks are created (must be on PATH)
#   - TEMPLATES_HOME: path where template symlinks are created
#
# Usage:
#   ./install.sh [OPTIONS]
#   ./install.sh --help
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"

readonly REPO_URL="https://github.com/fpmoles/dev-pack"
readonly REPO_NAME="dev-pack"
readonly MANIFEST_FILENAME=".dev-pack"

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
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Install dev-pack scripts, skills, agents, and templates onto this machine
by creating managed symlinks to the appropriate locations.

Options:
  -h, --help          Show this help message and exit
  -v, --verbose       Enable verbose output
  --install-hook      Install the post-merge git hook without prompting
  --skip-hook         Skip the git hook prompt
  --version           Show version and exit

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} --verbose
  ${SCRIPT_NAME} --install-hook

EOF
  exit 0
}

# ---------------------------------------------------------------------------
# Argument Parsing
# ---------------------------------------------------------------------------

VERBOSE=false
INSTALL_HOOK_FLAG=""

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        ;;
      --version)
        echo "${SCRIPT_NAME} version ${SCRIPT_VERSION}"
        exit 0
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      --install-hook)
        INSTALL_HOOK_FLAG="yes"
        shift
        ;;
      --skip-hook)
        INSTALL_HOOK_FLAG="no"
        shift
        ;;
      -*)
        error "Unknown option: $1"
        usage
        ;;
      *)
        error "Unexpected argument: $1"
        usage
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Dependency Check
# ---------------------------------------------------------------------------

check_dependencies() {
  local missing=false

  if ! command -v git &>/dev/null; then
    error "git is not installed or not on PATH."
    missing=true
  fi

  if [[ "${missing}" == true ]]; then
    error "Missing required dependencies. Run \${CODE_HOME}/local-setup/setup.sh to install them."
    exit 1
  fi

  if [[ "${VERBOSE}" == true ]]; then
    info "All dependencies satisfied."
  fi
}

# ---------------------------------------------------------------------------
# Environment Variable Validation
# ---------------------------------------------------------------------------

check_env_vars() {
  local missing=false

  for var in DEV_HOME CODE_HOME SCRIPTS_HOME TEMPLATES_HOME; do
    if [[ -z "${!var:-}" ]]; then
      error "Required environment variable \${${var}} is not set."
      missing=true
    else
      if [[ "${VERBOSE}" == true ]]; then
        info "${var}=${!var}"
      fi
    fi
  done

  if [[ "${missing}" == true ]]; then
    error "One or more required environment variables are missing."
    error "Run \${CODE_HOME}/local-setup/setup.sh to configure your environment."
    exit 1
  fi

  if [[ ":${PATH}:" != *":${SCRIPTS_HOME}:"* ]]; then
    warn "\${SCRIPTS_HOME} (${SCRIPTS_HOME}) is not on your PATH."
    warn "Scripts will be linked but won't be executable by name until PATH is updated."
    warn "Run \${CODE_HOME}/local-setup/setup.sh to configure your PATH."
  fi
}

# ---------------------------------------------------------------------------
# Repo Management
# ---------------------------------------------------------------------------

REPO_DIR=""

ensure_repo() {
  REPO_DIR="${CODE_HOME}/${REPO_NAME}"

  if [[ ! -d "${REPO_DIR}" ]]; then
    info "Cloning ${REPO_URL} into ${REPO_DIR}..."
    git clone "${REPO_URL}" "${REPO_DIR}" || { error "Failed to clone ${REPO_URL}"; exit 1; }
    success "Repository cloned to ${REPO_DIR}."
    return
  fi

  if [[ "${VERBOSE}" == true ]]; then
    info "Repository found at ${REPO_DIR}."
  fi

  local current_branch
  current_branch="$(git -C "${REPO_DIR}" rev-parse --abbrev-ref HEAD 2>/dev/null)" || {
    warn "Could not determine current branch. Skipping update check."
    return
  }

  if [[ "${current_branch}" != "main" ]]; then
    warn "Repository is on branch '${current_branch}', not main. Skipping pull."
    return
  fi

  info "Checking for updates on main branch..."
  git -C "${REPO_DIR}" fetch origin main --quiet 2>/dev/null || {
    warn "Could not fetch from remote. Continuing with local version."
    return
  }

  local local_sha remote_sha
  local_sha="$(git -C "${REPO_DIR}" rev-parse HEAD 2>/dev/null)"
  remote_sha="$(git -C "${REPO_DIR}" rev-parse origin/main 2>/dev/null)" || remote_sha=""

  if [[ -z "${remote_sha}" || "${local_sha}" == "${remote_sha}" ]]; then
    if [[ "${VERBOSE}" == true ]]; then
      info "Repository is up to date."
    fi
    return
  fi

  if ! git -C "${REPO_DIR}" diff --quiet || ! git -C "${REPO_DIR}" diff --cached --quiet; then
    warn "Local changes detected in ${REPO_DIR}. Skipping pull to preserve local state."
    return
  fi

  info "Pulling latest changes from main..."
  git -C "${REPO_DIR}" pull --ff-only origin main || {
    warn "Could not fast-forward. Skipping pull to preserve local state."
    return
  }
  success "Repository updated."
}

# ---------------------------------------------------------------------------
# Manifest Management
# ---------------------------------------------------------------------------

MANIFEST_FILE=""
OLD_MANIFEST=()
NEW_MANIFEST=()

load_manifest() {
  MANIFEST_FILE="${DEV_HOME}/${MANIFEST_FILENAME}"
  OLD_MANIFEST=()

  if [[ -f "${MANIFEST_FILE}" ]]; then
    while IFS= read -r line; do
      if [[ -z "${line}" ]]; then
        continue
      fi
      OLD_MANIFEST+=("${line}")
    done < "${MANIFEST_FILE}"
    if [[ "${VERBOSE}" == true ]]; then
      info "Loaded ${#OLD_MANIFEST[@]} manifest entries."
    fi
  else
    if [[ "${VERBOSE}" == true ]]; then
      info "No existing manifest found. Starting fresh."
    fi
  fi
}

record_manifest() {
  local entry="$1"
  NEW_MANIFEST+=("${entry}")
}

save_manifest() {
  printf '%s\n' "${NEW_MANIFEST[@]+"${NEW_MANIFEST[@]}"}" > "${MANIFEST_FILE}"
  if [[ "${VERBOSE}" == true ]]; then
    info "Manifest saved with ${#NEW_MANIFEST[@]} entries."
  fi
}

cleanup_removed() {
  local removed=0

  for old_entry in "${OLD_MANIFEST[@]+"${OLD_MANIFEST[@]}"}"; do
    local found=false
    for new_entry in "${NEW_MANIFEST[@]+"${NEW_MANIFEST[@]}"}"; do
      if [[ "${old_entry}" == "${new_entry}" ]]; then
        found=true
        break
      fi
    done

    if [[ "${found}" == false ]]; then
      local target="${old_entry#*:}"
      if [[ -L "${target}" ]]; then
        rm "${target}"
        success "Removed stale symlink: ${target}"
        (( removed++ )) || true
      fi
    fi
  done

  if [[ "${VERBOSE}" == true && "${removed}" -eq 0 ]]; then
    info "No stale symlinks to remove."
  fi
}

# ---------------------------------------------------------------------------
# Symlink Helper
# ---------------------------------------------------------------------------

create_symlink() {
  local source="$1"
  local target="$2"
  local manifest_type="$3"

  local target_dir
  target_dir="$(dirname "${target}")"

  if [[ ! -d "${target_dir}" ]]; then
    mkdir -p "${target_dir}"
    if [[ "${VERBOSE}" == true ]]; then
      info "Created directory: ${target_dir}"
    fi
  fi

  if [[ -L "${target}" ]]; then
    local existing_source
    existing_source="$(readlink "${target}")"
    if [[ "${existing_source}" == "${source}" ]]; then
      if [[ "${VERBOSE}" == true ]]; then
        info "Symlink up to date: ${target}"
      fi
      record_manifest "${manifest_type}:${target}"
      return
    fi
    rm "${target}"
    if [[ "${VERBOSE}" == true ]]; then
      info "Replacing stale symlink: ${target}"
    fi
  elif [[ -e "${target}" ]]; then
    warn "Path exists and is not a symlink: ${target} — skipping."
    return
  fi

  ln -s "${source}" "${target}"
  success "Linked: $(basename "${source}") -> ${target}"
  record_manifest "${manifest_type}:${target}"
}

# ---------------------------------------------------------------------------
# Install Scripts
# ---------------------------------------------------------------------------

install_scripts() {
  info "Installing scripts..."
  local scripts_dir="${REPO_DIR}/scripts"

  if [[ ! -d "${scripts_dir}" ]]; then
    warn "Scripts directory not found: ${scripts_dir}"
    return
  fi

  local count=0
  for script_file in "${scripts_dir}"/*.sh; do
    if [[ ! -e "${script_file}" ]]; then
      continue
    fi
    local script_name
    script_name="$(basename "${script_file}" .sh)"
    create_symlink "${script_file}" "${SCRIPTS_HOME}/${script_name}" "script"
    (( count++ )) || true
  done

  if [[ "${VERBOSE}" == true ]]; then
    info "Processed ${count} script(s)."
  fi
}

# ---------------------------------------------------------------------------
# Install Skills
# ---------------------------------------------------------------------------

install_skills() {
  info "Installing skills..."
  local skills_dir="${REPO_DIR}/skills"

  if [[ ! -d "${skills_dir}" ]]; then
    warn "Skills directory not found: ${skills_dir}"
    return
  fi

  local count=0
  for skill_dir in "${skills_dir}"/*/; do
    if [[ ! -d "${skill_dir}" ]]; then
      continue
    fi
    local skill_name
    skill_name="$(basename "${skill_dir}")"

    create_symlink "${skill_dir%/}" "${HOME}/.claude/skills/${skill_name}" "skill_claude"
    create_symlink "${skill_dir%/}" "${HOME}/.copilot/skills/${skill_name}" "skill_copilot"
    (( count++ )) || true
  done

  if [[ "${VERBOSE}" == true ]]; then
    info "Processed ${count} skill(s)."
  fi
}

# ---------------------------------------------------------------------------
# Install Agents
# ---------------------------------------------------------------------------

install_agents() {
  info "Installing agents..."
  local agents_dir="${REPO_DIR}/agents"

  if [[ ! -d "${agents_dir}" ]]; then
    warn "Agents directory not found: ${agents_dir}"
    return
  fi

  local count=0
  for agent_file in "${agents_dir}"/*; do
    if [[ ! -f "${agent_file}" ]]; then
      continue
    fi
    local agent_name
    agent_name="$(basename "${agent_file}")"

    create_symlink "${agent_file}" "${HOME}/.claude/agents/${agent_name}" "agent_claude"
    create_symlink "${agent_file}" "${HOME}/.copilot/agents/${agent_name}" "agent_copilot"
    (( count++ )) || true
  done

  if [[ "${VERBOSE}" == true ]]; then
    info "Processed ${count} agent(s)."
  fi
}

# ---------------------------------------------------------------------------
# Install Templates
# ---------------------------------------------------------------------------

install_templates() {
  info "Installing templates..."
  local templates_dir="${REPO_DIR}/templates"

  if [[ ! -d "${templates_dir}" ]]; then
    warn "Templates directory not found: ${templates_dir}"
    return
  fi

  local count=0
  for template_file in "${templates_dir}"/*; do
    if [[ ! -f "${template_file}" ]]; then
      continue
    fi
    local template_name
    template_name="$(basename "${template_file}")"
    create_symlink "${template_file}" "${TEMPLATES_HOME}/${template_name}" "template"
    (( count++ )) || true
  done

  if [[ "${VERBOSE}" == true ]]; then
    info "Processed ${count} template(s)."
  fi
}

# ---------------------------------------------------------------------------
# Git Hook Management
# ---------------------------------------------------------------------------

setup_git_hook() {
  local git_dir
  git_dir="$(git -C "${REPO_DIR}" rev-parse --git-dir 2>/dev/null)" || {
    warn "Could not determine git directory. Skipping hook setup."
    return
  }

  if [[ "${git_dir}" != /* ]]; then
    git_dir="${REPO_DIR}/${git_dir}"
  fi

  local hook_path="${git_dir}/hooks/post-merge"
  local hook_content
  hook_content="$(cat <<EOF
#!/usr/bin/env bash
# Managed by dev-pack install.sh — do not edit manually.
"${REPO_DIR}/install.sh" --skip-hook
EOF
)"

  if [[ -f "${hook_path}" ]]; then
    local existing_content
    existing_content="$(cat "${hook_path}")"
    if [[ "${existing_content}" != "${hook_content}" ]]; then
      echo "${hook_content}" > "${hook_path}"
      chmod +x "${hook_path}"
      success "Git post-merge hook updated."
    else
      if [[ "${VERBOSE}" == true ]]; then
        info "Git post-merge hook is already up to date."
      fi
    fi
    return
  fi

  local install_hook="${INSTALL_HOOK_FLAG}"

  if [[ -z "${install_hook}" ]]; then
    echo ""
    read -r -p "$(echo -e "${BLUE}[INFO]${NC}  Install a post-merge git hook to auto-update on pull? [y/N] ")" install_hook
  fi

  case "${install_hook}" in
    [Yy]|[Yy][Ee][Ss])
    echo "${hook_content}" > "${hook_path}"
    chmod +x "${hook_path}"
    success "Git post-merge hook installed at ${hook_path}."
      ;;
    *)
      info "Skipping git hook installation. Re-run ${SCRIPT_NAME} to install it later."
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  parse_args "$@"
  check_dependencies
  check_env_vars
  ensure_repo
  load_manifest

  install_scripts
  install_skills
  install_agents
  install_templates

  cleanup_removed
  save_manifest

  echo ""
  success "dev-pack installation complete."

  setup_git_hook
}

main "$@"
