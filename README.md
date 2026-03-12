# FPMoles Dev Pack

A curated collection of scripts, skills, agents, and templates installed onto a developer machine via managed symlinks.

## Table of Contents
- [Installation](#installation)
- [Components](#components)

## Installation

Run the install script to clone the repository (if needed), create symlinks, and optionally install a post-merge hook for automatic updates.

**Option 1 — run directly from GitHub (no prior clone needed):**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fpmoles/dev-pack/main/install.sh) [OPTIONS]
```

**Option 2 — clone first, then run:**
```bash
git clone https://github.com/fpmoles/dev-pack.git
cd dev-pack
./install.sh [OPTIONS]
```

**Dependencies**

| Dependency | Version  |
|------------|----------|
| `git`      | any      |
| `bash`     | 3.2+     |

**Required environment variables**

_Consider using [FPMoles Local Dev Setup](https://github.com/fpmoles/local-setup) to set these up automatically_

| Variable         | Description                                                   |
|------------------|---------------------------------------------------------------|
| `DEV_HOME`       | Developer home directory — manifest file is written here      |
| `CODE_HOME`      | Code directory — repository is cloned here                    |
| `SCRIPTS_HOME`   | Directory for script symlinks — must be on `PATH`             |
| `TEMPLATES_HOME` | Directory for template symlinks                               |

**Options**

| Flag             | Description                                       |
|------------------|---------------------------------------------------|
| `-h, --help`     | Show help and exit                                |
| `-v, --verbose`  | Enable verbose output                             |
| `--install-hook` | Install the post-merge git hook without prompting |
| `--skip-hook`    | Skip the git hook prompt                          |
| `--version`      | Show version and exit                             |

## Components

| Component | Location     | Installed to                             | Description                                   | Usage                      |
|-----------|--------------|------------------------------------------|-----------------------------------------------|----------------------------|
| Scripts   | `scripts/`   | `$SCRIPTS_HOME/<name>` (no extension)    | Executable bash utilities available on `PATH` | [Usage](scripts/README.md) |
| Skills    | `skills/`    | `~/.claude/skills/` `~/.copilot/skills/` | AI assistant skill definitions                | [Usage](skills/README.md)  |
| Agents    | `agents/`    | `~/.claude/agents/` `~/.copilot/agents/` | AI agent definitions                          | [Usage](agents/README.md)  |
| Templates | `templates/` | `$TEMPLATES_HOME/<name>`                 | Code templates for quick scaffolding          | N/A                        |

