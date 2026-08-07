#!/usr/bin/env bats
# Every script should print usage and exit 0 for -h/--help, without ever
# touching Docker (help is handled inside the arg-parsing loop, before the
# require_docker/require_command preflight checks).
#
# Mirrors tests/powershell/Help_Tests.ps1.
#
# Run with: bats tests/bash

load 'test_helper'

setup() {
    setup_common_vars
}

# ---- -h ---------------------------------------------------------------

@test "start.sh -h prints usage and exits 0" {
    run "${SCRIPT_DIR}/start.sh" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "stop.sh -h prints usage and exits 0" {
    run "${SCRIPT_DIR}/stop.sh" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "restart.sh -h prints usage and exits 0" {
    run "${SCRIPT_DIR}/restart.sh" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "health.sh -h prints usage and exits 0" {
    run "${SCRIPT_DIR}/health.sh" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "logs.sh -h prints usage and exits 0" {
    run "${SCRIPT_DIR}/logs.sh" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "backup.sh -h prints usage and exits 0" {
    run "${SCRIPT_DIR}/backup.sh" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "restore.sh -h prints usage and exits 0" {
    run "${SCRIPT_DIR}/restore.sh" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "cleanup.sh -h prints usage and exits 0" {
    run "${SCRIPT_DIR}/cleanup.sh" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

# ---- --help -------------------------------------------------------------

@test "start.sh --help exits 0" {
    run "${SCRIPT_DIR}/start.sh" --help
    [ "$status" -eq 0 ]
}

@test "stop.sh --help exits 0" {
    run "${SCRIPT_DIR}/stop.sh" --help
    [ "$status" -eq 0 ]
}

@test "restart.sh --help exits 0" {
    run "${SCRIPT_DIR}/restart.sh" --help
    [ "$status" -eq 0 ]
}

@test "health.sh --help exits 0" {
    run "${SCRIPT_DIR}/health.sh" --help
    [ "$status" -eq 0 ]
}

@test "logs.sh --help exits 0" {
    run "${SCRIPT_DIR}/logs.sh" --help
    [ "$status" -eq 0 ]
}

@test "backup.sh --help exits 0" {
    run "${SCRIPT_DIR}/backup.sh" --help
    [ "$status" -eq 0 ]
}

@test "restore.sh --help exits 0" {
    run "${SCRIPT_DIR}/restore.sh" --help
    [ "$status" -eq 0 ]
}

@test "cleanup.sh --help exits 0" {
    run "${SCRIPT_DIR}/cleanup.sh" --help
    [ "$status" -eq 0 ]
}
