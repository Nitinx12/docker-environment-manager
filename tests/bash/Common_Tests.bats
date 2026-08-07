#!/usr/bin/env bats
# Unit tests for scripts/bash/lib/common.sh.
#
# Mirrors tests/powershell/Common_Tests.ps1 where the underlying behavior
# actually matches. NOTE: unlike the PowerShell port, this common.sh has no
# Resolve-UnderRepoRoot-style helper - each script inlines its own relative
# path handling (see e.g. the OUTPUT_DIR check in backup.sh) - so instead
# these tests check the REPO_ROOT resolution common.sh itself does, plus
# its logging helpers and require_command/require_docker.
#
# Run with: bats tests/bash

load 'test_helper'

setup() {
    setup_common_vars
    EXPECTED_REPO_ROOT="$REPO_ROOT"
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/lib/common.sh"
}

# ---- REPO_ROOT resolution -------------------------------------------------

@test "sourcing common.sh resolves REPO_ROOT to the actual repo root" {
    # common.sh computes REPO_ROOT relative to its own file location
    # (lib/common.sh -> bash -> scripts -> repo root), independent of CWD.
    [ "$REPO_ROOT" = "$EXPECTED_REPO_ROOT" ]
}

# ---- Logging helpers -------------------------------------------------------

@test "log_info prints an [INFO] line containing the message" {
    run log_info "hello from test"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[INFO]"* ]]
    [[ "$output" == *"hello from test"* ]]
}

@test "log_warn prints a [WARN] line containing the message" {
    run log_warn "careful"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[WARN]"* ]]
    [[ "$output" == *"careful"* ]]
}

@test "log_error prints an [ERROR] line containing the message" {
    run log_error "boom"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[ERROR]"* ]]
    [[ "$output" == *"boom"* ]]
}

@test "log_success prints an [ OK ] line containing the message" {
    run log_success "done"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[ OK ]"* ]]
    [[ "$output" == *"done"* ]]
}

@test "log_info appends a plain-text line to LOG_FILE" {
    marker="test-marker-$$"
    log_info "$marker"
    [ -f "$LOG_FILE" ]
    grep -q "$marker" "$LOG_FILE"
}

# ---- load_env ---------------------------------------------------------
# common.sh's load_env sources REPO_ROOT/.env directly (via `set -a`), so
# quoting/comment/blank-line handling all come from bash's own parser.

@test "load_env sets a variable for each KEY=VALUE line" {
    TEMP_ENV_DIR="$(mktemp -d)"
    echo 'TEST_KEY=hello' > "${TEMP_ENV_DIR}/.env"

    REPO_ROOT="$TEMP_ENV_DIR" load_env
    [ "$TEST_KEY" = "hello" ]

    unset TEST_KEY
    rm -rf "$TEMP_ENV_DIR"
}

@test "load_env strips matching surrounding quotes" {
    TEMP_ENV_DIR="$(mktemp -d)"
    echo 'QUOTED_KEY="hello world"' > "${TEMP_ENV_DIR}/.env"

    REPO_ROOT="$TEMP_ENV_DIR" load_env
    [ "$QUOTED_KEY" = "hello world" ]

    unset QUOTED_KEY
    rm -rf "$TEMP_ENV_DIR"
}

@test "load_env ignores comments and blank lines" {
    TEMP_ENV_DIR="$(mktemp -d)"
    printf '# a comment\n\nTEST_KEY=value\n' > "${TEMP_ENV_DIR}/.env"

    REPO_ROOT="$TEMP_ENV_DIR" load_env
    [ "$TEST_KEY" = "value" ]

    unset TEST_KEY
    rm -rf "$TEMP_ENV_DIR"
}

@test "load_env does nothing when no .env file exists" {
    TEMP_ENV_DIR="$(mktemp -d)"

    run env REPO_ROOT="$TEMP_ENV_DIR" bash -c "source '${SCRIPT_DIR}/lib/common.sh'; load_env"
    [ "$status" -eq 0 ]

    rm -rf "$TEMP_ENV_DIR"
}

# ---- require_command / require_docker -------------------------------------

@test "require_command does not exit when the command exists" {
    run require_command bash
    [ "$status" -eq 0 ]
}

@test "require_command exits with code 1 (in a child process) when the command does not exist" {
    run bash -c "source '${SCRIPT_DIR}/lib/common.sh'; require_command definitely-not-a-real-command-xyz"
    [ "$status" -eq 1 ]
}

@test "require_docker succeeds when docker (mocked) is on PATH and info succeeds" {
    use_mock_docker
    run require_docker
    [ "$status" -eq 0 ]
    restore_path
}
