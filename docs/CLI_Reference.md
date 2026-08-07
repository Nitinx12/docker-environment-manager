# CLI Reference

Full flag reference for every script in `scripts/bash/`. PowerShell equivalents live in `scripts/powershell/` with **identical flag names and behavior** — see [PowerShell Equivalents](#powershell-equivalents) below.

Every script also accepts `-h` / `--help` for this same information at the terminal.

---

## Global Conventions

These apply to every script:

| Convention | Behavior |
|---|---|
| **Config precedence** | hardcoded default → `.env` value → CLI flag (CLI flags always win) |
| **Compose file resolution** | Relative paths are resolved against the repo root, not your current directory |
| **Logging** | Every log line prints to stdout/stderr (colored) *and* appends to `logs/docker-env-manager.log` (plain text) |
| **Exit codes** | `0` on success, `1` on any failure (bad flag, missing dependency, Docker error, health check failure, etc.) |
| **Preflight checks** | Every script verifies `docker` is installed and the Docker daemon is reachable before doing anything, and fails fast with a clear error if not |

---

## start.sh

Starts the Compose stack and waits for containers to report healthy.

```
./start.sh [OPTIONS]
```

| Flag | Description | Default |
|---|---|---|
| `-f, --file <path>` | Path to the Compose file | `.env`'s `COMPOSE_FILE`, or `docker/docker-compose.yml` |
| `-p, --project <name>` | Compose project name | `.env`'s `PROJECT_NAME`, or `docker-env-manager` |
| `-b, --build` | Rebuild images before starting | off |
| `-h, --help` | Show help | — |

**Behavior:** runs `docker compose up -d`, then polls every 3 seconds (up to `HEALTH_TIMEOUT` seconds, default `60`) until no container reports `"Health":"starting"`. Exits `1` immediately if any container reports `"Health":"unhealthy"`.

```bash
./start.sh                  # start with defaults
./start.sh -b                # rebuild images first
./start.sh -f custom.yml -p myapp
```

---

## stop.sh

Stops the Compose stack.

```
./stop.sh [OPTIONS]
```

| Flag | Description | Default |
|---|---|---|
| `-f, --file <path>` | Path to the Compose file | same as `start.sh` |
| `-p, --project <name>` | Compose project name | same as `start.sh` |
| `-v, --volumes` | Also remove named volumes declared in the compose file | off |
| `-h, --help` | Show help | — |

```bash
./stop.sh
./stop.sh -v                 # also drop named volumes
```

---

## restart.sh

Equivalent to `stop.sh` followed by `start.sh` with the same flags.

```
./restart.sh [OPTIONS]
```

| Flag | Description | Default |
|---|---|---|
| `-f, --file <path>` | Path to the Compose file | same as `start.sh` |
| `-p, --project <name>` | Compose project name | same as `start.sh` |
| `-b, --build` | Rebuild images before starting back up | off |
| `-h, --help` | Show help | — |

```bash
./restart.sh
./restart.sh -b
```

---

## cleanup.sh

Removes stopped/orphaned containers and dangling images for this project. Optionally extends to a host-wide prune.

```
./cleanup.sh [OPTIONS]
```

| Flag | Description | Default |
|---|---|---|
| `-f, --file <path>` | Path to the Compose file | same as `start.sh` |
| `-p, --project <name>` | Compose project name | same as `start.sh` |
| `-a, --all` | Also run a host-wide `docker system prune` (images, build cache, networks) | off |
| `-v, --volumes` | **Destructive.** Also remove this project's named volumes | off |
| `-n, --dry-run` | Show what would be removed without removing anything | off |
| `-h, --help` | Show help | — |

```bash
./cleanup.sh -n               # dry-run first — always a good idea
./cleanup.sh                  # project-scoped cleanup
./cleanup.sh -a -v             # host-wide prune, including volumes
```

---

## logs.sh

Views or streams logs for the Compose stack.

```
./logs.sh [OPTIONS] [SERVICE]
```

| Flag | Description | Default |
|---|---|---|
| `-f, --file <path>` | Path to the Compose file | same as `start.sh` |
| `-p, --project <name>` | Compose project name | same as `start.sh` |
| `-s, --service <name>` | Only show logs for this service (can also be given positionally) | all services |
| `--follow` | Stream logs continuously, like `tail -f` | off |
| `-n, --tail <lines>` | Number of lines to show from the end | `100` |
| `-h, --help` | Show help | — |

```bash
./logs.sh                     # last 100 lines, all services
./logs.sh --follow
./logs.sh -s api --follow
./logs.sh api                 # positional form, same as -s api
```

---

## health.sh

Reports, or waits for, container health status. Useful as a standalone CI step after `start.sh`, or for a manual spot-check.

```
./health.sh [OPTIONS]
```

| Flag | Description | Default |
|---|---|---|
| `-f, --file <path>` | Path to the Compose file | same as `start.sh` |
| `-p, --project <name>` | Compose project name | same as `start.sh` |
| `-w, --wait` | Wait out containers still `starting` instead of failing immediately | off |
| `-t, --timeout <secs>` | Max seconds to wait when `--wait` is set | `.env`'s `HEALTH_TIMEOUT`, or `60` |
| `-h, --help` | Show help | — |

**Exit codes:** `0` if every container with a healthcheck is healthy (or none define one). `1` if any container is unhealthy, or if `--wait` times out while containers are still starting.

```bash
./health.sh                   # one-shot check
./health.sh -w -t 120          # wait up to 2 minutes for a healthy stack
```

---

## backup.sh

Backs up Docker named volumes to timestamped `.tar.gz` archives, streamed through a throwaway `alpine` container (no host mount permissions required).

```
./backup.sh [OPTIONS]
```

| Flag | Description | Default |
|---|---|---|
| `-p, --project <name>` | Compose project name, used to auto-discover volumes | same as `start.sh` |
| `-v, --volume <name>` | Back up a specific volume (repeatable). Overrides project auto-discovery | auto-discover all project volumes |
| `-o, --output <dir>` | Directory to write backups to | `.env`'s `BACKUP_DIR`, or `./backups` |
| `-h, --help` | Show help | — |

**Behavior:** with no `-v` flags, discovers every volume Docker labeled with `com.docker.compose.project=<name>` and backs up each to `<volume>-<timestamp>.tar.gz`.

```bash
./backup.sh                              # back up every volume for the project
./backup.sh -v my_db_data                # back up one specific volume
./backup.sh -v my_db_data -o /mnt/backups
```

---

## restore.sh

Restores a named volume from a `.tar.gz` archive produced by `backup.sh`.

```
./restore.sh -v <volume> -i <backup-file> [OPTIONS]
```

| Flag | Description | Default |
|---|---|---|
| `-v, --volume <name>` | **Required.** Target volume name (created automatically if it doesn't exist) | — |
| `-i, --input <file>` | **Required.** Path to the `.tar.gz` backup archive | — |
| `-c, --clean` | Remove the volume's existing contents before restoring | off |
| `-y, --yes` | Skip the confirmation prompt | off |
| `-h, --help` | Show help | — |

**Behavior:** prompts for confirmation before restoring unless `-y` is passed. With `-c`, existing volume contents are deleted first — irreversible, so double-check the target volume name.

```bash
./restore.sh -v my_db_data -i ./backups/my_db_data-20260807-101500.tar.gz
./restore.sh -v my_db_data -i backup.tar.gz -c -y   # non-interactive, wipe first
```

---

## Bash and PowerShell Equivalents

Every script above has a `.ps1` counterpart in `scripts/powershell/` with the same flags (both short and long forms), same defaults, same `.env` precedence, and same exit codes.

| Bash | PowerShell |
|---|---|
| `start.sh` | `start.ps1` |
| `stop.sh` | `stop.ps1` |
| `restart.sh` | `restart.ps1` |
| `cleanup.sh` | `cleanup.ps1` |
| `logs.sh` | `logs.ps1` |
| `health.sh` | `health.ps1` |
| `backup.sh` | `backup.ps1` |
| `restore.sh` | `restore.ps1` |

```bash
./start.sh -b
./logs.sh --follow -s api
./health.sh -w -t 120
```

```powershell
.\start.ps1 -b
.\logs.ps1 --follow -s api
.\health.ps1 -w -t 120
```

Shell-specific requirements, logging, and testing/linting details: [`docs/BASH.md`](docs/BASH.md) and [`docs/POWERSHELL.md`](docs/POWERSHELL.md).

---

## Related Environment Variables

Read from `.env` at the repo root (see [`INSTALLATION.md#configuration`](INSTALLATION.md#configuration) for the core set). One additional variable is script-specific:

| Variable | Used by | Default |
|---|---|---|
| `BACKUP_DIR` | `backup.sh` | `./backups` |

---

## Related Documentation

| Doc | Covers |
|---|---|
| [`QUICKSTART.md`](QUICKSTART.md) | Fastest path to a running stack |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | System design, components, and data flow |
| [`INSTALLATION.md`](INSTALLATION.md) | Full setup, requirements, and `.env` configuration |
| [`docs/BASH.md`](docs/BASH.md) | Bash script usage, requirements, testing & linting |
| [`docs/POWERSHELL.md`](docs/POWERSHELL.md) | PowerShell-specific usage and parity notes |