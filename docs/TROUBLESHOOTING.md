# Troubleshooting

Common issues when using or contributing to Docker Environment Manager, and how to work through them. If you hit something not covered here, please open an issue — and consider adding it to this file once it's resolved.

## Docker & Compose

### "Cannot connect to the Docker daemon"
The Docker daemon isn't running, or your user doesn't have permission to talk to it.
- **Linux/macOS:** confirm Docker Desktop (or the `docker` service) is running; on Linux, check you're in the `docker` group (`groups $USER`) or are otherwise permitted to use the socket.
- **Windows/PowerShell:** confirm Docker Desktop is running and, if using WSL2, that the WSL integration is enabled for your distro under Docker Desktop → Settings → Resources → WSL Integration.

### "no such file or directory" for the compose file
The scripts default to a compose file path defined in `.env`. If you moved `docker-compose.yml` or renamed the `docker/` directory, update the path in `.env` or pass the override flag explicitly (see [`CLI_REFERENCE.md`](CLI_REFERENCE.md)) rather than editing the script defaults directly.

### `start` succeeds but `health` never reports ready
- Confirm the service you expect to be polled actually exposes a health check in `docker-compose.yml` — the health poller can only report what Docker itself knows about.
- Check `logs.sh` / `logs.ps1` output for the specific service; a container that's "running" but crash-looping under Compose can still read as unhealthy indefinitely.
- If health checks are genuinely slow (e.g. a database doing first-time initialization), the polling timeout may need to be increased — see the `health` command's timeout flag in `CLI_REFERENCE.md`.

### Backup or restore fails partway through
Backup/restore runs through a throwaway helper container. If it fails:
- Confirm the target volume actually exists (`docker volume ls`) — a typo'd volume name fails silently in some Docker versions rather than erroring clearly.
- Check available disk space where the backup archive is being written.
- Re-run with verbose/debug output if the script supports it, and include that output if you open an issue.

## PowerShell-Specific

### "cannot be loaded because running scripts is disabled on this system"
This is PowerShell's execution policy blocking unsigned local scripts — not a bug in this project. Fix it for your current user (doesn't require admin):
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### Paths with spaces or backslashes behave unexpectedly
PowerShell and Bash handle path escaping differently. If a `.env` value or CLI flag contains a Windows-style path, wrap it in quotes and prefer forward slashes where the script accepts them, to keep behavior consistent with the Bash side.

## Bash-Specific

### ShellCheck warnings on a script that "works fine"
"Works on my machine" isn't the bar — CI runs ShellCheck and will fail the build even if the script executes correctly. Run `shellcheck scripts/bash/<script>.sh` locally and resolve warnings before opening a PR, rather than suppressing them, unless there's a specific documented reason to.

### Bats tests fail only in CI, not locally
- Confirm you're testing against the same mocked `docker` binary the suite expects (see [`docs/BASH.md#testing--linting`](docs/BASH.md#testing--linting)) — a real Docker daemon on your machine can produce different output than the mock CI uses.
- Check for OS-specific assumptions (e.g. GNU vs BSD variants of `sed`/`date`) if the failure only shows on the macOS or Windows CI runners.

## Dev Container

### "Reopen in Container" fails or hangs
- Confirm Docker Desktop is running before opening the folder in VS Code — the Dev Container itself needs Docker to build.
- Try `Dev Containers: Rebuild Container Without Cache` from the command palette if a previous build is stuck in a bad state.
- Check the Dev Container build log (Terminal panel, "Dev Containers" output channel) for the actual failing step rather than assuming it's a project issue.

## Bash vs. PowerShell Behave Differently
This shouldn't happen — flags, defaults, and exit codes are meant to be identical across both. If you find a case where they diverge, that's a bug: please open an issue with the exact command run on both platforms and the differing output. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the parity requirement this project holds itself to.

## Still Stuck?

Open an issue with:
- OS and shell/version (`bash --version` or `$PSVersionTable`)
- Docker version (`docker --version`, `docker compose version`)
- The exact command you ran
- Full output, including any stack trace