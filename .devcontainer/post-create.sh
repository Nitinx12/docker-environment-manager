#!/usr/bin/env bash
# Runs once, automatically, after the dev container is built.
# Installs PSScriptAnalyzer (PowerShell's linter) and confirms everything
# your CI (step 9) will later check for is present and working.
set -euo pipefail

echo "Installing PSScriptAnalyzer module for PowerShell..."
pwsh -NoLogo -NoProfile -Command \
    "Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck"

echo ""
echo "Verifying toolchain:"
docker --version
docker compose version
shellcheck --version | head -2
# SC2016: single quotes are intentional here — $PSVersionTable must be
# expanded by pwsh, not by bash.
# shellcheck disable=SC2016
pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion'

echo ""
echo "Dev container ready. Try: ./scripts/bash/start.sh --help"