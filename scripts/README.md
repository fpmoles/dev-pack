# Scripts

Bash utilities installed as symlinks into `$SCRIPTS_HOME` (no file extension) and available on `PATH` after installation.

## git_cleanup

Deletes local Git branches that have already been merged into the default branch. Detects simple merges, squash merges, and rebase merges. Never deletes the current branch or the default branch.

**Dependencies:** `git`

```bash
git_cleanup [OPTIONS]
```

| Flag            | Description                                        |
|-----------------|----------------------------------------------------|
| `-h, --help`    | Show help and exit                                 |
| `-v, --verbose` | Enable verbose output                              |
| `-d, --dry-run` | Preview deletions without applying them            |
| `--version`     | Show version and exit                              |

**Examples**

```bash
# Preview which branches would be deleted
git_cleanup --dry-run

# Delete all merged branches
git_cleanup

# Verbose output
git_cleanup --verbose
```

---

## docker_proc

Starts or stops commonly used development Docker containers with consistent naming. Container naming convention: `docker_{tool}`.

**Dependencies:** `docker` (daemon must be running)

```bash
docker_proc [OPTIONS] <start|stop> <tool>
```

| Flag            | Description           |
|-----------------|-----------------------|
| `-h, --help`    | Show help and exit    |
| `-v, --verbose` | Enable verbose output |
| `--version`     | Show version and exit |

**Supported tools**

| Tool             | Image                              | Port   |
|------------------|------------------------------------|--------|
| `postgresql`     | `postgres:18` (default)            | `5432` |
| `swagger-editor` | `swaggerapi/swagger-editor:latest` | `8080` |
| `all`            | All tools above                    | —      |

**Examples**

```bash
# Start PostgreSQL
docker_proc start postgresql

# Start Swagger Editor
docker_proc start swagger-editor

# Start all tools
docker_proc start all
```

PostgreSQL data is persisted to `$DOCKER_DATA_HOME/{tool}` (defaults to `~/.docker/data/{tool}`).

Set `POSTGRESQL_IMAGE` to override the default image tag when needed (for example, `POSTGRESQL_IMAGE=postgres:19 docker_proc start postgresql`).

If you already have persisted PostgreSQL 17 data in `~/.docker/data/postgresql`, migrate it before switching defaults or recreate the container/data directory for a clean PostgreSQL 18 init.
