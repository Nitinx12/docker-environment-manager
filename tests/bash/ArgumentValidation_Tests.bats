#!/usr/bin/env bats
# Argument-parsing edge cases. These all fail inside each script's
# argument-parsing loop, before require_docker/require_command run, so no
# Docker (mocked or real) is needed for any test in this file.
#
# Mirrors tests/powershell/ArgumentValidation_Tests.ps1.
#
# Run with: bats tests/bash

load 'test_helper'

setup() {
    setup_common_vars
}

# ---- Unknown options are rejected ---------------------------------------
# logs.sh is deliberately excluded: unrecognized args are treated as a
# positional SERVICE name there, not rejected as unknown flags.

@test "start.sh --not-a-real-flag exits 1" {
    run "${SCRIPT_DIR}/start.sh" --not-a-real-flag
    [ "$status" -eq 1 ]
}

@test "stop.sh --not-a-real-flag exits 1" {
    run "${SCRIPT_DIR}/stop.sh" --not-a-real-flag
    [ "$status" -eq 1 ]
}

@test "restart.sh --not-a-real-flag exits 1" {
    run "${SCRIPT_DIR}/restart.sh" --not-a-real-flag
    [ "$status" -eq 1 ]
}

@test "health.sh --not-a-real-flag exits 1" {
    run "${SCRIPT_DIR}/health.sh" --not-a-real-flag
    [ "$status" -eq 1 ]
}

@test "backup.sh --not-a-real-flag exits 1" {
    run "${SCRIPT_DIR}/backup.sh" --not-a-real-flag
    [ "$status" -eq 1 ]
}

@test "cleanup.sh --not-a-real-flag exits 1" {
    run "${SCRIPT_DIR}/cleanup.sh" --not-a-real-flag
    [ "$status" -eq 1 ]
}

@test "restore.sh --not-a-real-flag exits 1" {
    run "${SCRIPT_DIR}/restore.sh" --not-a-real-flag
    [ "$status" -eq 1 ]
}

# ---- logs.sh treats an unrecognized arg as a service name --------------

@test "logs.sh does not exit 1 purely for having an extra positional arg" {
    # Point at a compose file that doesn't exist so it fails later, for a
    # different, expected reason - not because "myservice" was rejected as
    # an unknown flag.
    missing_compose="${BATS_TEST_TMPDIR}/no-such-compose.yml"
    run "${SCRIPT_DIR}/logs.sh" -f "$missing_compose" myservice
    [[ "$output" == *"Compose file not found"* ]]
}

# ---- Flags that require a value fail cleanly when the value is missing -

@test "start.sh -p with no value exits 1" {
    run "${SCRIPT_DIR}/start.sh" -p
    [ "$status" -eq 1 ]
}

@test "backup.sh -o with no value exits 1" {
    run "${SCRIPT_DIR}/backup.sh" -o
    [ "$status" -eq 1 ]
}

@test "health.sh -t with no value exits 1" {
    run "${SCRIPT_DIR}/health.sh" -t
    [ "$status" -eq 1 ]
}

@test "restore.sh -v with no value exits 1" {
    run "${SCRIPT_DIR}/restore.sh" -v
    [ "$status" -eq 1 ]
}

# ---- restore.sh requires both -v and -i ---------------------------------

@test "restore.sh exits 1 when -i is missing" {
    run "${SCRIPT_DIR}/restore.sh" -v somevolume -y
    [ "$status" -eq 1 ]
}

@test "restore.sh exits 1 when -v is missing" {
    run "${SCRIPT_DIR}/restore.sh" -i somefile.tar.gz -y
    [ "$status" -eq 1 ]
}
