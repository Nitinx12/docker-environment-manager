# Bash scripts (Linux / macOS / WSL)

These are the primary implementation of the Docker Environment Manager toolkit — the `.ps1` files in `scripts/powershell/` are drop-in equivalents for Windows, built to the same flags, same defaults, same exit codes, same `.env` file. Pick whichever shell fits your OS.

## Layout

Expected repo structure (matches the PowerShell side):

```
<repo>/
  .env                          # optional, see .env.example
  docker/docker-compose.yml
  scripts/
    bash/
      lib/common.sh
      start.sh
      stop.sh
      restart.sh
      cleanup.sh
      logs.sh
      health.sh
      backup.sh
      restore.sh
    powershell/
      lib/common.ps1
      start.ps1 ...
```

`lib/common.sh` must stay next to the scripts (`scripts/bash/lib/`) — each script sources it and uses it to find the repo root, load `.env`, and run preflight checks.

## Requirements

- Bash 3.2+ (macOS's default system Bash works fine — nothing here uses Bash 4+-only features like `declare -A` or `${var,,}`). Bash 4.0+/5.x, as shipped on Linux, WSL2, and the project's Dev Container, is recommended.
- Docker Desktop / Docker Engine with the Compose plugin (`docker compose`, not the legacy `docker-compose` binary)
- Optional, for linting and tests: [ShellCheck](https://www.shellcheck.net/) 0.9+ and [Bats-core](https://github.com/bats-core/bats-core)

## Usage

```bash
# Start the stack (rebuilding images first)
./start.sh -b

# Tail logs for one service
./logs.sh --follow -s api

# Wait up to 120s for a healthy stack
./health.sh -w -t 120

# Back up every volume tagged for this project
./backup.sh

# Back up one specific volume to a custom folder
./backup.sh -v my_db_data -o /mnt/backups

# Restore a volume from a backup, skipping the confirmation prompt
./restore.sh -v my_db_data -i /mnt/backups/my_db_data-20260807-101500.tar.gz -y

# Dry-run a full cleanup
./cleanup.sh -a -n
```

Every script accepts `-h` / `--help` for full usage text. Full flag-by-flag documentation lives in [`CLI_REFERENCE.md`](../CLI_REFERENCE.md).

## Logging

Every script sources `lib/common.sh`, which provides `log_info` / `log_warn` / `log_error` / `log_success`. Each call prints a colored line to stdout/stderr **and** appends a plain-text line to `logs/docker-env-manager.log` at the repo root — so CI output and local history both stay useful. The log directory is created automatically on first run.

## Notes on parity with the PowerShell scripts

- Precedence is identical: hardcoded default → `.env` value → CLI flag.
- `restart.sh` shells out to `stop.sh` then `start.sh`, just like `restart.ps1` calls `stop.ps1`/`start.ps1`.
- Health/readiness checks parse `docker compose ps --format json` the same way the PowerShell scripts do (counting `"Health":"unhealthy"` / `"Health":"starting"` occurrences via `grep -c`), so behavior matches across every supported Docker Compose version.
- Volume backup/restore use the same throwaway-`alpine` container pattern, so no host-side `tar` is required.
- Compose file paths passed with `-f`/`--file` are resolved relative to the repo root, not your current working directory, so scripts behave the same no matter where you invoke them from.

If you get a "Permission denied" error running a script directly, make it executable first:

```bash
chmod +x scripts/bash/*.sh scripts/bash/lib/*.sh
```

## Testing & Linting

CI (`.github/workflows/tests.yml`) runs both of these on every push and PR, on `ubuntu-latest`:

```bash
# Lint (the -x flag follows sourced files, e.g. lib/common.sh)
shellcheck -x scripts/bash/*.sh
shellcheck -x scripts/bash/lib/*.sh

# Run the test suite
bats tests/bash
```

Install locally with:

```bash
# Debian/Ubuntu
sudo apt-get install -y bats shellcheck

# macOS
brew install bats-core shellcheck
```

The Bats suite (`tests/bash/*.bats`) uses a stub `docker` binary at `tests/bash/mocks/docker` so tests exercise script logic (argument parsing, health-check counting, backup/restore flows) without needing a real Docker daemon. `tests/bash/test_helper.bash` wires this up via `use_mock_docker` / `restore_path` helpers called from each test file's `setup()` / `teardown()`.

Before running the tests directly (outside CI), make sure everything is executable:

```bash
chmod +x scripts/bash/*.sh scripts/bash/lib/*.sh tests/bash/mocks/docker
```