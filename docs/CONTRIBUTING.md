# Contributing to Docker Environment Manager

Thanks for taking the time to contribute. This project's core promise is that Bash and PowerShell users get an identical experience that only holds if every change keeps both script sets in sync. This guide covers what that means in practice.

## Before You Start

- Check open [issues](https://github.com/Nitinx12/docker-environment-manager/issues) and [pull requests](https://github.com/Nitinx12/docker-environment-manager/pulls) to avoid duplicate work.
- For anything larger than a small fix (new command, changed flag behavior, new config option), open an issue first to discuss the approach before writing code.

## Development Setup

The fastest path to a working environment is the provided Dev Container, which gives you Docker CLI access, PowerShell, Bats, ShellCheck, and PSScriptAnalyzer pre-installed:

```bash
git clone https://github.com/Nitinx12/docker-environment-manager.git
cd docker-environment-manager
code .   # then "Reopen in Container" when prompted
```

If you'd rather set up manually, see [`INSTALLATION.md`](INSTALLATION.md) for the required tool versions.

## The Golden Rule: Parity

Every script exists as both a `.sh` and a `.ps1` with the same flags, same defaults, and same exit codes. **If you touch one, mirror the change in the other.** This includes:

| If you change... | Also update... |
|---|---|
| `scripts/bash/<name>.sh` | `scripts/powershell/<name>.ps1` |
| A flag, default, or exit code | Both scripts, plus [`CLI_REFERENCE.md`](CLI_REFERENCE.md) |
| Bash-specific behavior/docs | [`docs/BASH.md`](docs/BASH.md) |
| PowerShell-specific behavior/docs | [`docs/POWERSHELL.md`](docs/POWERSHELL.md) |
| `.env` variables or config shape | [`INSTALLATION.md`](INSTALLATION.md) |

A PR that changes only one language's script without the other will not be merged as-is expect a review comment asking for the mirrored change.

## Making Changes

1. Fork the repo and create a branch off `main`:
   ```bash
   git checkout -b fix/short-description
   ```
2. Make your change in both `scripts/bash/` and `scripts/powershell/` as needed.
3. Update the relevant docs (see the parity table above).
4. Add or update tests for both languages — see below.
5. Run the full test and lint suite locally before opening a PR.

## Testing & Linting

Both suites run against a mocked `docker` binary, so you don't need a real Docker daemon.

**Bash** (from repo root):
```bash
bats tests/bash
shellcheck scripts/bash/*.sh
```

**PowerShell** (from repo root):
```powershell
Invoke-Pester -Path ./tests/powershell
Invoke-ScriptAnalyzer -Path ./scripts/powershell -Recurse
```

See [`docs/BASH.md#testing--linting`](docs/BASH.md#testing--linting) and [`docs/POWERSHELL.md#testing--linting`](docs/POWERSHELL.md#testing--linting) for details on what each check enforces.

CI runs all of the above ShellCheck + Bats for Bash, PSScriptAnalyzer + Pester for PowerShell across a 3-OS matrix on every push. A PR won't be merged with failing checks.

## Commit Messages

Keep commits focused and descriptive. Prefix with the area affected where it helps review, e.g.:

```
scripts: add --timeout flag to health.sh/ps1
docs: document new --timeout flag in CLI_REFERENCE.md
tests: cover --timeout flag in bash + powershell suites
```

## Pull Request Checklist

Before opening a PR, confirm:

- [ ] Bash and PowerShell scripts are in parity (same flags, defaults, exit codes)
- [ ] `bats tests/bash` passes
- [ ] `Invoke-Pester -Path ./tests/powershell` passes
- [ ] `shellcheck` and `Invoke-ScriptAnalyzer` report no new warnings
- [ ] Relevant docs updated (`CLI_REFERENCE.md`, `docs/BASH.md`, `docs/POWERSHELL.md`, `README.md` as applicable)
- [ ] PR description explains the *why*, not just the *what*

## Reporting Bugs

Open an issue with:
- OS and shell (Bash version / PowerShell version)
- The exact command you ran
- Expected vs. actual behavior
- Relevant output from `logs/` if applicable

## Questions

If something in this guide is unclear, open an issue — that's a sign the guide needs fixing too.
