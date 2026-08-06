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
pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion'

echo ""
echo "Dev container ready. Try: ./scripts/bash/start.sh --help"