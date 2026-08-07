# PowerShell scripts (Windows / cross-platform)

These are drop-in PowerShell equivalents of the Bash scripts in
`scripts/bash/`, built for the Docker Environment Manager toolkit. Same
flags, same defaults, same exit codes, same `.env` file — pick whichever
shell fits your OS.

## Layout

Expected repo structure (matches the Bash side):

```
<repo>/
  .env                          # optional, see .env.example
  docker/docker-compose.yml
  scripts/
    bash/
      lib/common.sh
      start.sh ...
    powershell/
      lib/common.ps1
      start.ps1
      stop.ps1
      restart.ps1
      cleanup.ps1
      logs.ps1
      health.ps1
      backup.ps1
      restore.ps1
```

`lib/common.ps1` must stay next to the scripts (`scripts/powershell/lib/`) —
each script dot-sources it and uses it to find the repo root, load `.env`,
and run preflight checks.

## Requirements

- PowerShell 5.1+ (Windows PowerShell) or PowerShell 7+ (`pwsh`, cross-platform)
- Docker Desktop / Docker Engine with the Compose plugin (`docker compose`, not the old `docker-compose`)

## Usage

```powershell
# Start the stack (rebuilding images first)
.\start.ps1 -b

# Tail logs for one service
.\logs.ps1 --follow -s api

# Wait up to 120s for a healthy stack
.\health.ps1 -w -t 120

# Back up every volume tagged for this project
.\backup.ps1

# Back up one specific volume to a custom folder
.\backup.ps1 -v my_db_data -o D:\backups

# Restore a volume from a backup, skipping the confirmation prompt
.\restore.ps1 -v my_db_data -i D:\backups\my_db_data-20260807-101500.tar.gz -y

# Dry-run a full cleanup
.\cleanup.ps1 -a -n
```

Every script accepts `-h` / `--help` for full usage text, and both the
short (`-p`) and long (`--project`) flag spellings shown in each script's
Bash counterpart.

## Notes on parity with the Bash scripts

- Precedence is identical: hardcoded default -> `.env` value -> CLI flag.
- `restart.ps1` shells out to `stop.ps1` then `start.ps1`, just like `restart.sh` calls `stop.sh`/`start.sh`.
- Health/readiness checks parse `docker compose ps --format json` the same
  way the Bash scripts do (counting `"Health":"unhealthy"` /
  `"Health":"starting"` occurrences), so behavior matches across every
  supported Docker Compose version.
- Volume backup/restore use the same throwaway-`alpine` container pattern,
  so no host-side `tar` is required on Windows.

If you hit a PowerShell execution-policy error running these locally, run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

before invoking the scripts in that session (this doesn't change any
system-wide policy).