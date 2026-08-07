# PowerShell scripts (Windows / cross-platform)

These are drop-in PowerShell equivalents of the Bash scripts in `scripts/bash/`, built for the Docker Environment Manager toolkit. Same flags, same defaults, same exit codes, same `.env` file — pick whichever shell fits your OS.

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

`lib/common.ps1` must stay next to the scripts (`scripts/powershell/lib/`) — each script dot-sources it and uses it to find the repo root, load `.env`, and run preflight checks.

## Requirements

- PowerShell 5.1+ (Windows PowerShell) or PowerShell 7.2+ (`pwsh`, cross-platform — this is what the Dev Container installs)
- Docker Desktop / Docker Engine with the Compose plugin (`docker compose`, not the legacy `docker-compose` binary)
- Optional, for linting and tests: [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) and [Pester](https://pester.dev/) 5.7.1

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

Every script accepts `-h` / `--help`, and both the short (`-p`) and long (`--project`) flag spellings shown in each script's Bash counterpart — these are parsed manually from `$args` rather than through PowerShell's native parameter binding, which is why the syntax stays identical across both shells. Full flag-by-flag documentation lives in [`CLI_REFERENCE.md`](../CLI_REFERENCE.md).

If you hit a PowerShell execution-policy error running these locally, run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

before invoking the scripts in that session (this doesn't change any system-wide policy).

## Logging

Every script dot-sources `lib/common.ps1`, which provides `log_info` / `log_warn` / `log_error` / `log_success`. These print color-coded lines via `Write-Host` (Cyan/Yellow/Red/Green).

**Difference from the Bash side:** the Bash `log_*` helpers also append every line to `logs/docker-env-manager.log` at the repo root; the PowerShell versions currently only write to the console and do not mirror that file. Keep this in mind if you're relying on the log file for a mixed Bash/PowerShell workflow — only the Bash-side scripts populate it.

## Notes on parity with the Bash scripts

- Precedence is identical: hardcoded default → `.env` value → CLI flag.
- `restart.ps1` shells out to `stop.ps1` then `start.ps1`, just like `restart.sh` calls `stop.sh`/`start.sh`.
- Health/readiness checks parse `docker compose ps --format json` the same way the Bash scripts do (counting `"Health":"unhealthy"` / `"Health":"starting"` occurrences, via regex matching instead of `grep -c`), so behavior matches across every supported Docker Compose version.
- Volume backup/restore use the same throwaway-`alpine` container pattern, so no host-side `tar` is required on Windows.
- Compose file and input-file paths are resolved relative to the repo root via `Resolve-UnderRepoRoot`, mirroring each Bash script's `[[ "$X" != /* ]]` check.
- **Logging is not identical** — see [Logging](#logging) above.

## Testing & Linting

CI (`.github/workflows/tests.yml`) runs the PowerShell suite across a three-OS matrix (`ubuntu-latest`, `windows-latest`, `macos-latest`) on every push and PR:

```powershell
# Install tooling (pinned versions match CI)
Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser -Force -SkipPublisherCheck
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck

# Lint
Invoke-ScriptAnalyzer scripts/powershell -Recurse -Severity Error

# Run the test suite
Invoke-Pester -Path ./tests/powershell
```

The Pester suite (`tests/powershell/*.Tests.ps1`) uses a stub `docker` so tests exercise script logic without a real Docker daemon. On non-Windows runners this is a Bash script (`tests/powershell/mocks/docker`); on Windows, `mocks/docker.cmd` shims to the same script via Git Bash, since PowerShell's command resolution won't find an extensionless file directly. You don't need to worry about this locally unless you're modifying the test mocks themselves.
