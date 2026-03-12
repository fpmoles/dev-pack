# Skills

AI assistant skill definitions installed as symlinks into `~/.claude/skills/` and `~/.copilot/skills/`.

Each skill is a directory containing one or more markdown prompt files. Skills are invoked by referencing them in the AI assistant chat.

---

## fpm_bash_scripter

Generates and validates bash scripts against the project's standard conventions. Scripts target Bash 3.2 compatibility and remain valid on Bash 4+.

### create_script

Generates a complete, ready-to-use bash script following all project conventions.

```
Using #create_script, create a bash script that <description>
```

**Input:** A description of what the script should do, its required arguments, and any dependencies.
**Output:** A complete `.sh` file with shebang, safety flags, header comment, argument parsing, dependency checks, and a `main()` entry point.

### validate_script

Reviews an existing bash script against project conventions and produces a pass/fail report with actionable fixes.

```
Using #validate_script, validate #<script_file>
```

**Input:** An existing `.sh` file.
**Output:** A structured report listing each convention check as ✅ pass or ❌ fail, with a 💡 fix for every failure.
