#!/usr/bin/env bats
# Integration tests that run each script for real, but with a fake
# `docker` executable (tests/bash/mocks/docker) prepended to PATH so
# nothing here needs an actual Docker daemon or Compose stack.
#
# Mirrors tests/powershell/Docker_Integration_Tests.ps1.
#
# NOTE: the mock must be executable:
#   chmod +x tests/bash/mocks/docker
#
# Run with: bats tests/bash

load 'test_helper'

setup() {
    setup_common_vars
    use_mock_docker

    COMPOSE_FILE="${BATS_TEST_TMPDIR}/compose.yml"
    cat > "$COMPOSE_FILE" <<'EOF'
services:
  demo:
    image: alpine
EOF
}

teardown() {
    restore_path
}

@test "start.sh starts the stack and reports healthy" {
    run "${SCRIPT_DIR}/start.sh" -f "$COMPOSE_FILE" -p testproj
    [ "$status" -eq 0 ]
}

@test "health.sh reports healthy immediately, no waiting needed" {
    run "${SCRIPT_DIR}/health.sh" -f "$COMPOSE_FILE" -p testproj
    [ "$status" -eq 0 ]
}

@test "stop.sh stops the stack cleanly" {
    run "${SCRIPT_DIR}/stop.sh" -f "$COMPOSE_FILE" -p testproj
    [ "$status" -eq 0 ]
}

@test "restart.sh calls stop.sh then start.sh and exits 0" {
    run "${SCRIPT_DIR}/restart.sh" -f "$COMPOSE_FILE" -p testproj
    [ "$status" -eq 0 ]
}

@test "cleanup.sh dry run exits 0 without needing -y or removing anything" {
    run "${SCRIPT_DIR}/cleanup.sh" -f "$COMPOSE_FILE" -p testproj -n
    [ "$status" -eq 0 ]
}

@test "backup.sh writes an archive via docker cp for an explicitly named volume" {
    export MOCK_DOCKER_VOLUMES="testproj_data"
    OUT_DIR="${BATS_TEST_TMPDIR}/backups"
    mkdir -p "$OUT_DIR"

    run "${SCRIPT_DIR}/backup.sh" -p testproj -v testproj_data -o "$OUT_DIR"
    [ "$status" -eq 0 ]

    archive_count="$(find "$OUT_DIR" -name '*.tar.gz' | wc -l)"
    [ "$archive_count" -gt 0 ]

    unset MOCK_DOCKER_VOLUMES
}

@test "backup.sh fails cleanly when the named volume does not exist" {
    export MOCK_DOCKER_VOLUMES="testproj_data"
    OUT_DIR="${BATS_TEST_TMPDIR}/backups"
    mkdir -p "$OUT_DIR"

    run "${SCRIPT_DIR}/backup.sh" -p testproj -v does-not-exist -o "$OUT_DIR"
    [ "$status" -eq 1 ]

    unset MOCK_DOCKER_VOLUMES
}

@test "restore.sh copies the archive into the restore container and exits 0" {
    export MOCK_DOCKER_VOLUMES="testproj_data"
    BACKUP_FILE="${BATS_TEST_TMPDIR}/restore-src.tar.gz"
    echo 'fake archive bytes' > "$BACKUP_FILE"

    run "${SCRIPT_DIR}/restore.sh" -v testproj_data -i "$BACKUP_FILE" -y
    [ "$status" -eq 0 ]

    unset MOCK_DOCKER_VOLUMES
}

@test "restore.sh fails cleanly when the input file does not exist" {
    export MOCK_DOCKER_VOLUMES="testproj_data"
    MISSING="${BATS_TEST_TMPDIR}/no-such.tar.gz"

    run "${SCRIPT_DIR}/restore.sh" -v testproj_data -i "$MISSING" -y
    [ "$status" -eq 1 ]

    unset MOCK_DOCKER_VOLUMES
}
