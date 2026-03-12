# fpm_bash_scripter Skill

A skill for generating and validating bash scripts against the project's standard conventions,
with Bash syntax that works on macOS system Bash 3.2 and remains valid on Bash 4+.

---

## Tasks

### 1. Create Script (`create_script.md`)

Generates a new bash script following the project's standard conventions for structure, safety,
error handling, argument parsing, and output formatting.

**Usage:**
In GitHub Copilot Chat, run:
```
Using #create_script, create a bash script that <description>
```

**Input:** A description of what the script should do, its required arguments, and any dependencies.
**Output:** A complete, ready-to-use `.sh` file following all conventions.

---

### 2. Validate Script (`validate_script.md`)

Reviews an existing bash script against the project's conventions and produces a pass/fail report
with actionable fixes for every violation found.

**Usage:**
In GitHub Copilot Chat, run:
```
Using #validate_script, validate #<script_file>
```

**Input:** An existing `.sh` file.
**Output:** A structured report listing each convention check as ✅ pass or ❌ fail, with a 💡 fix for every failure.

---

## Conventions

Every script in this project must follow these rules:

### Bash compatibility baseline

- Target **Bash 3.2 compatibility first** because that is the default Bash on many macOS systems
- Only use syntax that also works unchanged on Bash 4+
- Prefer portable Bash patterns such as `case`, indexed arrays, and `while IFS= read -r`
- Avoid Bash 4+-only features unless the user explicitly requires them and a compatible fallback is provided

#### Avoid these Bash 4+-only features by default

- `${var,,}` and `${var^^}` case conversion
- `declare -A` associative arrays
- `mapfile` / `readarray`
- `local -n` namerefs
- `coproc`
- `globstar` (`**`) patterns that require `shopt -s globstar`

#### Prefer these compatible alternatives

- Use `case` for case-insensitive yes/no handling instead of `${var,,}`
- Use indexed arrays or newline-delimited loops instead of associative arrays
- Use `while IFS= read -r line; do ...; done` instead of `mapfile`
- Use explicit `if` statements for optional logging and branching instead of terse Bash-version-sensitive shortcuts when `set -e` is enabled

### Structure

| Section | Rule |
|---------|------|
| Shebang | `#!/usr/bin/env bash` — always first line |
| Safety flags | `set -euo pipefail` — always second non-comment line |
| Header comment | Block comment describing the script, prerequisites, and usage |
| Script directory | `SCRIPT_DIR` resolved via `BASH_SOURCE[0]` |
| Constants | `readonly` UPPER_SNAKE_CASE variables declared before functions |
| Output helpers | `info`, `success`, `warn`, `error` functions using ANSI colours |
| Argument parsing | `parse_args()` function using a `while`/`case` loop |
| Dependency checks | `check_dependencies()` function verifying required tools |
| Entry point | `main()` function called as the last line with `main "$@"` |

### Output helpers

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

### Argument parsing

```bash
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)    usage ;;
      -v|--verbose) VERBOSE=true; shift ;;
      -*)           error "Unknown option: $1"; usage ;;
      *)            POSITIONAL="$1"; shift ;;
    esac
  done
}
```

### Entry point

```bash
main() {
  parse_args "$@"
  check_dependencies
  # logic in named functions
}

main "$@"
```

### Coding rules

- Always double-quote variable expansions: `"$VAR"`, `"${VAR}"`
- Use `[[ ]]` for conditionals, not `[ ]`
- Use `local` for all variables inside functions
- Use `|| { error "msg"; exit 1; }` for inline error handling
- Prefer explicit `if` blocks over standalone `[[ ... ]] && ...` when a false condition is expected during normal execution
- Send errors to stderr via the `error` helper
- Use 2-space indentation
- Functions use lower_snake_case naming

