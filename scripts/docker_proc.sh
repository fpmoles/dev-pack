#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# docker_proc.sh
# Start or stop commonly used development Docker containers with consistent
# naming. Container naming convention: docker_{tool}
#
# Usage:
#   ./docker_proc.sh [OPTIONS] <start|stop> <tool>
#   ./docker_proc.sh --help
#
# Supported tools:
#   postgresql     PostgreSQL database server
#   swagger-editor Swagger Editor
#   all            All supported tools
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
# Constants
# ---------------------------------------------------------------------------

readonly SUPPORTED_TOOLS=("postgresql" "swagger-editor" "all")
readonly SUPPORTED_COMMANDS=("start" "stop")

# ---------------------------------------------------------------------------
# PostgreSQL Configuration
# ---------------------------------------------------------------------------

readonly POSTGRESQL_CONTAINER="docker_postgresql"
# Pin a stable default major; callers can override via POSTGRESQL_IMAGE env var.
readonly POSTGRESQL_IMAGE="${POSTGRESQL_IMAGE:-postgres:18}"
readonly POSTGRESQL_PORT="5432"
readonly POSTGRESQL_USER="postgres"
readonly POSTGRESQL_PASSWORD="postgres"
readonly POSTGRESQL_DB="local"
readonly POSTGRESQL_PGDATA="/var/lib/postgresql/data/pgdata"

# ---------------------------------------------------------------------------
# Swagger Editor Configuration
# (Swagger Editor is stateless — no persistent data directory required)
# ---------------------------------------------------------------------------

readonly SWAGGER_EDITOR_CONTAINER="docker_swagger-editor"
readonly SWAGGER_EDITOR_IMAGE="swaggerapi/swagger-editor:latest"
readonly SWAGGER_EDITOR_PORT="8080"

# ---------------------------------------------------------------------------
# Data Directory Resolution
# ---------------------------------------------------------------------------

# Returns the base data directory, preferring DOCKER_DATA_HOME env var.
# Falls back to ~/.docker/data if the variable is not set.
resolve_docker_data_home() {
  echo "${DOCKER_DATA_HOME:-${HOME}/.docker/data}"
}

# Returns the data directory for a named tool and ensures it exists.
tool_data_dir() {
  local tool="$1"
  local dir
  dir="$(resolve_docker_data_home)/${tool}"
  mkdir -p "${dir}"
  echo "${dir}"
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

usage() {
  local exit_code="${1:-0}"
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS] <start|stop> <tool>

Start or stop commonly used development Docker containers.
Container naming convention: docker_{tool}

Commands:
  start          Start the specified tool container(s)
  stop           Stop the specified tool container(s)

Supported tools:
  postgresql     PostgreSQL ${POSTGRESQL_IMAGE} on port ${POSTGRESQL_PORT}
  swagger-editor Swagger Editor ${SWAGGER_EDITOR_IMAGE} on port ${SWAGGER_EDITOR_PORT}
  all            Apply command to all supported tools

Options:
  -h, --help     Show this help message and exit
  -v, --verbose  Enable verbose output
  --version      Show version and exit

Examples:
  ${SCRIPT_NAME} start postgresql
  ${SCRIPT_NAME} stop postgresql
  ${SCRIPT_NAME} start all
  ${SCRIPT_NAME} stop all

EOF
  exit "${exit_code}"
}

# ---------------------------------------------------------------------------
# Argument Parsing
# ---------------------------------------------------------------------------

VERBOSE=false
COMMAND=""
TOOL=""

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
      -*)
        error "Unknown option: $1"
        usage 1
        ;;
      *)
        if [[ -z "${COMMAND}" ]]; then
          COMMAND="$1"
        elif [[ -z "${TOOL}" ]]; then
          TOOL="$1"
        else
          error "Unexpected argument: $1"
          usage 1
        fi
        shift
        ;;
    esac
  done

  if [[ -z "${COMMAND}" ]]; then
    error "No command specified."
    usage 1
  fi

  local valid_cmd=false
  for c in "${SUPPORTED_COMMANDS[@]}"; do
    [[ "${COMMAND}" == "${c}" ]] && valid_cmd=true && break
  done
  if [[ "${valid_cmd}" == false ]]; then
    error "Unsupported command: ${COMMAND}"
    error "Supported commands: ${SUPPORTED_COMMANDS[*]}"
    exit 1
  fi

  if [[ -z "${TOOL}" ]]; then
    error "No tool specified."
    usage 1
  fi

  local valid_tool=false
  for t in "${SUPPORTED_TOOLS[@]}"; do
    [[ "${TOOL}" == "${t}" ]] && valid_tool=true && break
  done
  if [[ "${valid_tool}" == false ]]; then
    error "Unsupported tool: ${TOOL}"
    error "Supported tools: ${SUPPORTED_TOOLS[*]}"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Dependency Check
# ---------------------------------------------------------------------------

check_dependencies() {
  if ! command -v docker &>/dev/null; then
    error "Docker is not installed or not on PATH."
    error "Install Docker Desktop: https://www.docker.com/products/docker-desktop/"
    exit 1
  fi

  if ! docker info &>/dev/null; then
    error "Docker daemon is not running. Please start Docker and try again."
    exit 1
  fi

  [[ "${VERBOSE}" == true ]] && info "Docker is available and running"
}

# ---------------------------------------------------------------------------
# Helper — check if a container is already running
# ---------------------------------------------------------------------------

container_running() {
  local name="$1"
  docker ps --format '{{.Names}}' | grep -qx "${name}"
}

container_exists() {
  local name="$1"
  docker ps -a --format '{{.Names}}' | grep -qx "${name}"
}

# ---------------------------------------------------------------------------
# Tool: PostgreSQL
# ---------------------------------------------------------------------------

start_postgresql() {
  info "Starting PostgreSQL..."

  if container_running "${POSTGRESQL_CONTAINER}"; then
    warn "Container '${POSTGRESQL_CONTAINER}' is already running — skipping."
    return
  fi

  if container_exists "${POSTGRESQL_CONTAINER}"; then
    info "Restarting existing container '${POSTGRESQL_CONTAINER}'..."
    docker start "${POSTGRESQL_CONTAINER}"
  else
    local data_dir
    data_dir="$(tool_data_dir "postgresql")"
    [[ "${VERBOSE}" == true ]] && info "Using data directory: ${data_dir}"

    [[ "${VERBOSE}" == true ]] && info "Pulling image ${POSTGRESQL_IMAGE}..."
    docker pull "${POSTGRESQL_IMAGE}"

    docker run \
      --detach \
      --name "${POSTGRESQL_CONTAINER}" \
      --publish "${POSTGRESQL_PORT}:5432" \
      --env POSTGRES_USER="${POSTGRESQL_USER}" \
      --env POSTGRES_PASSWORD="${POSTGRESQL_PASSWORD}" \
      --env POSTGRES_DB="${POSTGRESQL_DB}" \
      --env PGDATA="${POSTGRESQL_PGDATA}" \
      --volume "${data_dir}:/var/lib/postgresql/data" \
      --restart unless-stopped \
      "${POSTGRESQL_IMAGE}"
  fi

  success "PostgreSQL started."
  info  "  Container : ${POSTGRESQL_CONTAINER}"
  info  "  Host      : localhost:${POSTGRESQL_PORT}"
  info  "  User      : ${POSTGRESQL_USER}"
  info  "  Password  : ${POSTGRESQL_PASSWORD}"
  info  "  Database  : ${POSTGRESQL_DB}"
  info  "  Data dir  : $(tool_data_dir "postgresql")"
  info  "  Stop with : ${SCRIPT_NAME} stop postgresql"
}

stop_postgresql() {
  info "Stopping PostgreSQL..."

  if ! container_running "${POSTGRESQL_CONTAINER}"; then
    warn "Container '${POSTGRESQL_CONTAINER}' is not running — skipping."
    return
  fi

  docker stop "${POSTGRESQL_CONTAINER}"
  success "PostgreSQL stopped (container '${POSTGRESQL_CONTAINER}' preserved)."
}

# ---------------------------------------------------------------------------
# Tool: Swagger Editor
# ---------------------------------------------------------------------------

start_swagger_editor() {
  info "Starting Swagger Editor..."

  if container_running "${SWAGGER_EDITOR_CONTAINER}"; then
    warn "Container '${SWAGGER_EDITOR_CONTAINER}' is already running — skipping."
    return
  fi

  if container_exists "${SWAGGER_EDITOR_CONTAINER}"; then
    info "Restarting existing container '${SWAGGER_EDITOR_CONTAINER}'..."
    docker start "${SWAGGER_EDITOR_CONTAINER}"
  else
    [[ "${VERBOSE}" == true ]] && info "Pulling image ${SWAGGER_EDITOR_IMAGE}..."
    docker pull "${SWAGGER_EDITOR_IMAGE}"

    docker run \
      --detach \
      --name "${SWAGGER_EDITOR_CONTAINER}" \
      --publish "${SWAGGER_EDITOR_PORT}:80" \
      --restart unless-stopped \
      "${SWAGGER_EDITOR_IMAGE}"
  fi

  success "Swagger Editor started."
  info  "  Container : ${SWAGGER_EDITOR_CONTAINER}"
  info  "  URL       : http://localhost:${SWAGGER_EDITOR_PORT}"
  info  "  Stop with : ${SCRIPT_NAME} stop swagger-editor"
}

stop_swagger_editor() {
  info "Stopping Swagger Editor..."

  if ! container_running "${SWAGGER_EDITOR_CONTAINER}"; then
    warn "Container '${SWAGGER_EDITOR_CONTAINER}' is not running — skipping."
    return
  fi

  docker stop "${SWAGGER_EDITOR_CONTAINER}"
  success "Swagger Editor stopped (container '${SWAGGER_EDITOR_CONTAINER}' preserved)."
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

dispatch() {
  case "${COMMAND}" in
    start)
      case "${TOOL}" in
        postgresql)     start_postgresql ;;
        swagger-editor) start_swagger_editor ;;
        all)            start_postgresql; start_swagger_editor ;;
      esac
      ;;
    stop)
      case "${TOOL}" in
        postgresql)     stop_postgresql ;;
        swagger-editor) stop_swagger_editor ;;
        all)            stop_postgresql; stop_swagger_editor ;;
      esac
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  parse_args "$@"
  check_dependencies
  dispatch
}

main "$@"
