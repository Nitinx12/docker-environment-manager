# Quick Start

Get the stack running in under five minutes. For full setup details, platform requirements, and troubleshooting, see [`INSTALLATION.md`](INSTALLATION.md).

---

## Prerequisites

- Docker Desktop (or Docker Engine + Compose plugin) running
- VS Code + the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) *(skip if going the manual route)*

---

## 1. Clone the repository

```bash
git clone https://github.com/Nitinx12/docker-environment-manager.git
cd docker-environment-manager
```

## 2. Open the Dev Container

```bash
code .
```

Click **"Reopen in Container"** when VS Code prompts you. This builds the toolchain (Docker CLI, PowerShell, ShellCheck) automatically — no manual installs needed.

> **Going manual instead?** Skip straight to step 3 as long as `docker`, `docker compose`, and `bash` (or `pwsh`) are already on your machine. See [`INSTALLATION.md`](INSTALLATION.md#manual-installation-without-dev-containers) for exact packages.

## 3. Start the stack

```bash
./scripts/bash/start.sh -b
```

`-b` rebuilds images before starting. Drop it on subsequent runs for a faster start.

**PowerShell equivalent:**
```powershell
.\scripts\powershell\start.ps1 -b
```

## 4. Verify it's running

```bash
./scripts/bash/health.sh
```

The default Compose file (`docker/docker-compose.yml`) ships with a placeholder `demo` service — an nginx container on port `8081` — so you can confirm everything works end-to-end before wiring up your real services:

```bash
curl -I http://localhost:8081
```

You should get a `200 OK`.

## 5. Stop the stack

```bash
./scripts/bash/stop.sh
```

Add `-v` / `--volumes` if you also want to drop named volumes.

---

## Cheat Sheet

| Task | Command |
|---|---|
| Start (rebuild first) | `./scripts/bash/start.sh -b` |
| Stop | `./scripts/bash/stop.sh` |
| Restart | `./scripts/bash/restart.sh` |
| Tail logs | `./scripts/bash/logs.sh --follow` |
| Check health | `./scripts/bash/health.sh -w -t 120` |
| Back up volumes | `./scripts/bash/backup.sh` |
| Clean up resources | `./scripts/bash/cleanup.sh` |

Every script accepts `-h` / `--help` for full options.

---

## Next Steps

- Swap the placeholder `demo` service in `docker/docker-compose.yml` for your real stack
- Adjust `PROJECT_NAME`, `COMPOSE_FILE`, and `HEALTH_TIMEOUT` in `.env` — see [`INSTALLATION.md`](INSTALLATION.md#configuration)
- Full flag reference for every script: [`CLI_REFERENCE.md`](CLI_REFERENCE.md)
- Running natively (no Dev Container)? See [`docs/BASH.md`](docs/BASH.md) for Linux/macOS/WSL, or [`docs/POWERSHELL.md`](docs/POWERSHELL.md) for Windows/PowerShell
- Run the test suite: `tests/bash/*.bats` (Bats) and `tests/powershell/*.Tests.ps1` (Pester)