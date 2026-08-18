# AGENTS.md

<!-- Guidance for AI coding agents (and humans) working in this repo. -->
<!-- Read ARCHITECTURE.md first if you need the "why", not just the "how". -->

## What this project is

Docker Environment Manager is a **thin automation layer over Docker Compose** —
not a service, not a daemon. It's a set of scripts (mirrored 1:1 in Bash and
PowerShell) that wrap `docker compose` with consistent logging, `.env`
loading, health polling, and volume backup/restore.

There is no build step and no package to install. The deliverable is the
`scripts/` directory itself, dropped into other projects.

## Ground rule: Bash and PowerShell are peers

<!-- This is the single most important convention in the repo. -->

Every script exists twice: `scripts/bash/<name>.sh` and
`scripts/powershell/<name>.ps1`. They must share:

- the same flags (`-p`/`--project`, `-b`/`--build`, `-v`/`--volume`, etc.)
- the same defaults
- the same exit codes
- the same observable behavior

**If you edit one, mirror the change in the other in the same commit.**
A PR that changes only one language's script for anything other than a
language-specific bug fix should be treated as incomplete.

## Repo layout (quick map)

```
scripts/bash/            # bash implementation + lib/common.sh
scripts/powershell/      # powershell implementation + lib/common.ps1
docker/docker-compose.yml # placeholder demo stack (nginx:alpine)
tests/bash/               # Bats suite + mocks/docker
tests/powershell/         # Pester suite + mocks/docker
.devcontainer/            # reproducible dev environment
.env                      # PROJECT_NAME, COMPOSE_FILE, HEALTH_TIMEOUT, BACKUP_DIR
```

## Required workflow: edit a file -> run its tests

<!-- Non-negotiable. Do this before considering any change finished. -->

Whenever you edit a file under `scripts/bash/`, run the Bash suite:

```bash
bats tests/bash
shellcheck scripts/bash/**/*.sh
```

Whenever you edit a file under `scripts/powershell/`, run the PowerShell
suite:

```powershell
Invoke-Pester -Path ./tests/powershell
Invoke-ScriptAnalyzer -Path ./scripts/powershell -Recurse
```

If you edit **both** implementations (the common case — see ground rule
above), run **both** test suites before calling the change done. Neither
suite needs a real Docker daemon; both run against the stub `docker` binary
in `tests/*/mocks/docker`, so there's no excuse to skip this because "Docker
isn't available."

Never mark a task complete with a failing test. If a test fails and the
failure looks like an outdated test rather than a real bug, fix the test
in the same commit and say so explicitly — don't silently loosen it.

## Conventions to preserve

<!-- These are load-bearing design decisions from ARCHITECTURE.md. -->
<!-- Don't "fix" them without reading the rationale there first. -->

- **No `jq` dependency at runtime.** Health/status parsing uses `grep -c`
  (Bash) / regex (PowerShell) against `docker compose ps --format json`
  text, on purpose, so scripts run outside the Dev Container too.
- **Config precedence is always**: hardcoded default -> `.env` -> CLI flag.
  Keep this order identical in every script.
- **Fail fast.** Every script calls `require_docker` / `require_command`
  before doing real work. Don't skip this in new scripts.
- **Volume operations go through a throwaway `alpine` container**, never a
  direct host bind-mount — this is what keeps backup/restore identical
  across Linux, macOS, and Windows.
- **`restore.sh`/`restore.ps1` never auto-discover volumes.** Restoring is
  destructive; explicit `-v`/`-i` flags are required, and a confirmation
  prompt is required unless `-y`/`--yes` is passed. Don't relax this.
- **PowerShell logging is console-only** (no file log), while Bash logging
  also appends to `logs/docker-env-manager.log`. This asymmetry is
  documented, not a bug — don't "fix" it by adding file logging to
  PowerShell without discussing it first.

## Adding a new script

If you add a 9th user-facing script:

1. Implement it in **both** `scripts/bash/` and `scripts/powershell/`.
2. Source/dot-source the shared lib (`common.sh` / `common.ps1`) for
   logging, `.env` loading, and preflight checks — don't reimplement them.
3. Add a Bats file under `tests/bash/` and a Pester file under
   `tests/powershell/`, both using the existing `mocks/docker` stub.
4. Update `CLI_REFERENCE.md` and both `docs/BASH.md` / `docs/POWERSHELL.md`.
5. Run both test suites (see above) before opening a PR.

## Style

- Bash: pass ShellCheck clean. No `bashisms` disabled without a comment
  explaining why.
- PowerShell: pass PSScriptAnalyzer clean. Flags are parsed manually from
  `$args` (not native parameter binding) — this is intentional, to keep
  `-p`/`--project` working identically in both shells. Don't convert
  scripts to idiomatic `-Project` style parameters.
- Comments should explain *why*, not restate the line above them.

## CI expectations

`tests.yml` runs on every push/PR: lint + test both script sets.
`release.yml` (triggered on `v*.*.*` tags) calls `tests.yml` via
`workflow_call` first — a release cannot ship if any test fails. Don't
add a path that skips this gate.

## Where to look for more detail

| Question | Doc |
|---|---|
| How is this all wired together? | `ARCHITECTURE.md` |
| How do I run it locally? | `QUICKSTART.md` |
| Full setup / `.env` reference | `INSTALLATION.md` |
| Every flag, every script | `CLI_REFERENCE.md` |
| Bash-specific details | `docs/BASH.md` |
| PowerShell-specific details | `docs/POWERSHELL.md` |