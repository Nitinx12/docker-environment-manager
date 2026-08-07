#!/usr/bin/env bash
# Shared setup for the Bats suite in tests/bash.
#
# Run the whole suite with:
#   bats tests/bash
# Requires bats-core: https://github.com/bats-core/bats-core
#   Debian/Ubuntu: apt-get install bats
#   macOS:         brew install bats-core
#
# NOTE ON LAYOUT: these tests assume the bash ports of the PowerShell
# scripts live at scripts/bash/*.sh, with a shared scripts/bash/lib/common.sh
# - mirroring the existing scripts/powershell layout one-for-one. If your
# bash scripts live somewhere else, update SCRIPT_DIR below (it's the only
# place the path is defined).

# Resolves REPO_ROOT/SCRIPT_DIR/MOCK_BIN_DIR for the currently running test
# file. Call this from `setup()` in every .bats file, the same way each
# .ps1 file computes $RepoRoot/$ScriptDir in its BeforeAll block.
setup_common_vars() {
    REPO_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
    SCRIPT_DIR="${REPO_ROOT}/scripts/bash"
    MOCK_BIN_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/mocks" && pwd)"
}

# Prepends the mocked `docker` to PATH for the duration of a test file.
# Equivalent of Docker_Integration_Tests.ps1's $env:PATH manipulation.
use_mock_docker() {
    ORIGINAL_PATH="$PATH"
    PATH="${MOCK_BIN_DIR}:${PATH}"
}

# Restores the real PATH. Call from `teardown()` whenever use_mock_docker
# was used in `setup()`.
restore_path() {
    PATH="$ORIGINAL_PATH"
}
