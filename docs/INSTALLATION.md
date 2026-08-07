# Installation Guide

This project ships a preconfigured **Dev Container** (`.devcontainer/`) so you get a consistent, ready-to-use environment — Docker CLI, PowerShell, and ShellCheck — without installing anything by hand. This is the recommended setup path. A manual, no-Dev-Container path is also documented below.

---

## Supported Platforms

| Platform | Dev Container | Native Bash scripts | Native PowerShell scripts |
|---|:---:|:---:|:---:|
| Windows 10/11 | ✅ (Docker Desktop + WSL2 backend) | Via WSL2 or Git Bash | ✅ Windows PowerShell 5.1 or `pwsh` 7+ |
| macOS (Intel & Apple Silicon) | ✅ (Docker Desktop) | ✅ Native | ✅ `pwsh` 7+ |
| Linux | ✅ (Docker Engine + Compose plugin) | ✅ Native | ✅ `pwsh` 7+ |

The Dev Container itself is Debian-based (`bookworm`), so once you're inside it, behavior is identical regardless of host OS.

---

## Minimum Requirements

| Tool | Minimum Version | Notes |
|---|---|---|
| Docker Engine | 20.10+ | Provides the Compose V2 plugin used throughout the scripts |
| Docker Compose | v2.6+ (plugin, `docker compose`) | Health checks parse `docker compose ps --format json`, added in v2.6. The legacy standalone `docker-compose` (v1) binary is **not** supported |
| VS Code | 1.85+ | Only needed for the Dev Container workflow; keep it updated for the smoothest Dev Containers experience |
| Dev Containers extension | Latest | `ms-vscode-remote.remote-containers`, installed from the VS Code Marketplace |
| PowerShell | 5.1+ (Windows PowerShell) or 7.2+ (`pwsh`, cross-platform) | Needed only for `scripts/powershell/*`; not required if you stick to the Bash scripts |
| ShellCheck | 0.9+ | Needed only if linting `scripts/bash/*` outside the Dev Container |

Inside the Dev Container, exact tool versions are pinned for you via `.devcontainer/devcontainer-lock.json` (`docker-outside-of-docker@1.10.0`, `powershell@2.0.2`) — no manual version-matching required.

---

## Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/Nitinx12/docker-environment-manager.git
   cd docker-environment-manager
   ```

2. **Open in VS Code**
   ```bash
   code .
   ```

3. **Reopen in Container**
   When prompted, click **"Reopen in Container"**.
   If you don't see the prompt, open the Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`) and run:
   ```
   Dev Containers: Reopen in Container
   ```

4. **Wait for the build**
   VS Code will:
   - Build the image from `.devcontainer/Dockerfile`
   - Install the `docker-outside-of-docker` and `powershell` features
   - Run `post-create.sh` automatically, which installs **PSScriptAnalyzer** and verifies the toolchain

5. **You're in.** Once the container is ready, a terminal inside VS Code drops you into the container as the `vscode` user with everything installed.

---

## What's Included

**Base image:** `mcr.microsoft.com/devcontainers/base:bookworm` (Debian-based)

**Installed via `Dockerfile`:**

| Package | Purpose |
|---|---|
| `shellcheck` | Bash script linting |
| `jq` | JSON processing in shell scripts |
| `curl` | HTTP requests / downloads |
| `ca-certificates` | TLS trust store |

**Installed via Dev Container features:**

| Feature | Version | Purpose |
|---|---|---|
| `docker-outside-of-docker` | 1.10.0 | Proxies `docker` / `docker compose` to the **host's** Docker engine |
| `powershell` | 2.0.2 | Installs PowerShell Core (`pwsh`) for the `.ps1` scripts |

**Installed via `post-create.sh`:** `PSScriptAnalyzer` (PowerShell's linter), plus a toolchain verification pass.

**VS Code extensions (auto-installed):** `timonwong.shellcheck`, `ms-vscode.powershell`, `ms-azuretools.vscode-docker`

---

## Configuration

Copy the example env file and adjust it for your environment:

```bash
cp .env.example .env   # if .env.example exists — otherwise edit .env directly
```

| Variable | Default | Purpose |
|---|---|---|
| `PROJECT_NAME` | `docker-env-manager` | Used for `docker compose -p` / container name prefixing |
| `COMPOSE_FILE` | `docker/docker-compose.yml` | Path to the Compose file, relative to the repo root |
| `HEALTH_TIMEOUT` | `60` | Seconds `start.sh` waits for containers to report healthy before giving up |

Precedence for every setting is: **hardcoded default → `.env` value → CLI flag** (CLI flags always win).

---

## CLI Reference

All scripts live in `scripts/bash/` (and their PowerShell equivalents in `scripts/powershell/`). Every script supports `-h` / `--help` for full usage.

| Script | Purpose |
|---|---|
| `start.sh` | Start the Compose stack |
| `stop.sh` | Stop the Compose stack |
| `restart.sh` | Stop then start |
| `cleanup.sh` | Clean up Docker resources |
| `logs.sh` | View/stream service logs |
| `health.sh` | Check or wait for stack health |
| `backup.sh` | Back up named volumes to `.tar.gz` |
| `restore.sh` | Restore a volume from a `.tar.gz` backup |

Full flag-by-flag documentation, defaults, and examples for every script (Bash and PowerShell): [`CLI_REFERENCE.md`](CLI_REFERENCE.md).

---

## Verifying Your Installation

`post-create.sh` runs these checks automatically on container creation, but you can re-run them anytime from inside the container:

```bash
docker --version
docker compose version
shellcheck --version
pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion'
```

All four commands should return version info with no errors. Then confirm the project's entry point is reachable:

```bash
./scripts/bash/start.sh --help
```

---

## Manual Installation (without Dev Containers)

If you'd rather not use VS Code / Dev Containers, you can replicate the environment manually on Debian/Ubuntu. For Bash-specific version requirements and script details, see [`docs/BASH.md`](docs/BASH.md); for PowerShell, see [`docs/POWERSHELL.md`](docs/POWERSHELL.md).

```bash
# System packages
sudo apt-get update
sudo apt-get install -y shellcheck jq curl ca-certificates

# Docker (if not already installed)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"   # log out/in for group change to take effect

# PowerShell (Core)
sudo apt-get install -y wget apt-transport-https software-properties-common
wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell

# PSScriptAnalyzer
pwsh -Command "Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck"
```

On macOS, use Homebrew equivalents (`brew install shellcheck jq docker powershell`).
On Windows, install Docker Desktop, PowerShell 7+, and ShellCheck (via `choco install shellcheck` or WSL) directly.

> **Note:** the manual path skips the Docker-outside-of-Docker isolation the Dev Container provides — your scripts will simply use whatever Docker daemon is already running on your machine.

---

## Troubleshooting

| Issue | Fix |
|---|---|
| "Reopen in Container" never appears | Command Palette → `Dev Containers: Reopen in Container` |
| `docker` command not found inside the container | Confirm Docker Desktop is running on the host — Docker-outside-of-Docker proxies to the host daemon, it doesn't run its own |
| `Install-Module` fails during `post-create.sh` | Usually a transient PowerShell Gallery network issue — reopen the container to retry, or run the command manually inside the container |
| Container build is slow the first time | Normal — subsequent rebuilds use Docker layer caching and are much faster |

---

## Uninstalling / Resetting

To rebuild the environment from scratch:
1. Command Palette → `Dev Containers: Rebuild Container Without Cache`
2. Or delete the container/image manually via Docker Desktop and reopen in VS Code

---

## Next Steps

- **Start the stack:** `./scripts/bash/start.sh -b` (rebuilds images, then starts)
- **Check it's healthy:** `./scripts/bash/health.sh -w -t 120`
- **Tail logs:** `./scripts/bash/logs.sh --follow`
- **Run the test suite:** Bash tests use [Bats](https://github.com/bats-core/bats-core) (`tests/bash/*.bats`); PowerShell tests use [Pester](https://pester.dev/) (`tests/powershell/*.Tests.ps1`)
- **Set up backups:** `./scripts/bash/backup.sh` to snapshot named volumes on a schedule
- Windows users working outside the Dev Container: see [`docs/POWERSHELL.md`](docs/POWERSHELL.md) for the PowerShell script equivalents

---

## Related Documentation

| Doc | Covers |
|---|---|
| [`QUICKSTART.md`](QUICKSTART.md) | Fastest path to a running stack |
| [`CLI_REFERENCE.md`](CLI_REFERENCE.md) | Every script, every flag, defaults, and examples |
| [`README.md`](README.md) | Project overview |
| [`docs/BASH.md`](docs/BASH.md) | Bash script usage, requirements, testing & linting |
| [`docs/POWERSHELL.md`](docs/POWERSHELL.md) | PowerShell script usage, parity notes with Bash, execution-policy fix |
| [Configuration](#configuration) (this doc) | `.env` variables and precedence rules |
| [`.github/workflows/`](.github/workflows) | CI (`tests.yml`) and release (`release.yml`) pipelines |