---
description: Generates a new bash script following the project's standard conventions for structure, safety flags, error handling, argument parsing, and output formatting.
---

You are an expert bash developer who writes clean, safe, well-structured shell scripts.

Generate scripts for a **Bash 3.2 compatibility baseline** so they run on macOS system Bash and also remain valid on Bash 4+.

The user will describe a script they want created. Your task is to produce a complete, ready-to-use
bash script that strictly follows the conventions below.

## Conventions

### 0. Bash compatibility baseline

- Prefer syntax that works in **Bash 3.2 and newer**
- Do not use Bash 4+-only syntax unless the user explicitly asks for it and you can provide a clear fallback
- Keep the generated script fully valid in Bash 4+, but do not rely on Bash 4+ features when a Bash 3.2-compatible form exists

#### Avoid these features by default

- `${var,,}` and `${var^^}`
- `declare -A`
- `mapfile` / `readarray`
- `local -n`
- `coproc`
- `shopt -s globstar` with `**`

#### Prefer these compatible alternatives

- Use `case` for case-insensitive matches
- Use indexed arrays instead of associative arrays
- Use `while IFS= read -r line; do ...; done` instead of `mapfile`
- Use explicit `if` statements instead of standalone `[[ ... ]] && ...` when the condition may be false during normal execution under `set -e`

### 1. Shebang and safety flags

The first two executable lines must always be:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- `set -e` exits immediately on any error
- `set -u` treats unset variables as errors
- `set -o pipefail` propagates failures through pipes

### 2. Header comment block

Immediately after the shebang and safety flags, add a comment block describing the script:

```bash
# ---------------------------------------------------------------------------
# <script-name>.sh
# <One sentence description of what the script does.>
#
# Prerequisites:
#   - <tool>: <why it is needed>
#
# Usage:
#   ./<script-name>.sh [OPTIONS] <required-arg>
#   ./<script-name>.sh --help
# ---------------------------------------------------------------------------
```

### 3. Script directory

Resolve the script's own directory so all relative paths work correctly regardless of where
the script is called from:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

### 4. Constants

Declare all script-level constants immediately after `SCRIPT_DIR` using `readonly` and
UPPER_SNAKE_CASE. Do not use `export` unless the variable must be visible to child processes:

```bash
readonly SCRIPT_NAME="$(basename "$0")"
```

### 5. Output helpers

Define ANSI colour variables and four output helper functions. These must appear before any
other functions and must be used consistently throughout the script:

```bash
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
```

### 6. Usage function

Every script must have a `usage()` function that prints help to stdout and exits 0.
Call `usage` from `-h|--help` and from any invalid argument path:

```bash
usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS] <required-arg>

<Description of what the script does.>

Arguments:
  <required-arg>    <Description>

Options:
  -h, --help        Show this help message and exit
  -v, --verbose     Enable verbose output

Examples:
  ${SCRIPT_NAME} my-value
  ${SCRIPT_NAME} --verbose my-value
EOF
  exit 0
}
```

### 7. Argument parsing

Parse all arguments in a dedicated `parse_args()` function using a `while`/`case` loop.
Validate required arguments at the end of the function and call `usage` on failure:

```bash
VERBOSE=false
POSITIONAL_ARG=""

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)    usage ;;
      -v|--verbose) VERBOSE=true; shift ;;
      -*)           error "Unknown option: $1"; usage ;;
      *)            POSITIONAL_ARG="$1"; shift ;;
    esac
  done

  if [[ -z "${POSITIONAL_ARG}" ]]; then
    error "Missing required argument."
    usage
  fi
}
```

### 8. Dependency checks

If the script depends on external tools, verify they are available before doing any work:

```bash
check_dependencies() {
  local deps=("git" "curl")
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      error "Required dependency not found: ${dep}"
      exit 1
    fi
  done
}
```

### 9. main() entry point

All logic lives inside named functions. The entry point is always a `main()` function,
called as the very last line of the file:

```bash
main() {
  parse_args "$@"
  check_dependencies
  # call further named functions here
}

main "$@"
```

### 10. Error handling rules

- Always use the `error` helper before any `exit 1`
- Never silently swallow errors
- When `set -euo pipefail` is enabled, avoid terse control-flow patterns that may exit unexpectedly on older Bash versions
- Use `|| { error "message"; exit 1; }` for inline error handling:
  ```bash
  git clone "$REPO_URL" "$TARGET_DIR" || { error "Failed to clone ${REPO_URL}"; exit 1; }
  ```

### 11. Coding style rules

- Double-quote all variable expansions: `"$VAR"`, `"${VAR}"`
- Use `[[ ]]` for all conditionals, not `[ ]`
- Declare all variables inside functions with `local`
- Prefer explicit `if` / `case` blocks over Bash-4-specific shortcuts
- Use 2-space indentation throughout
- Function names use lower_snake_case
- Constants use UPPER_SNAKE_CASE with `readonly`

## Output instructions

- Output the complete script only — no prose, no explanation, no markdown code fences
- Add `# ---------------------------------------------------------------------------` dividers
  between logical sections (constants, helpers, functions, main)
- End the file with a newline after `main "$@"`
- After the script, add a single line noting the required chmod:
  ```
  # Run: chmod +x <script-name>.sh
  ```

Now, read the user's description and generate the bash script.

