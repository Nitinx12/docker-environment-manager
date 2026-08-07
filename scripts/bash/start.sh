#!/usr/bin/env bash
#
# start.sh — Start the Docker Compose stack for this project.
#
# Usage:
#   ./start.sh [-f|--file <compose-file>] [-p|--project <name>] [-b|--build] [-h|--help]
#
# Reads defaults from ../../.env (see .env.example), which can be overridden
# by flags on the command line.

set -euo pipefail

# ---- Load shared helpers ------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=SCRIPTDIR/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Start the Docker Compose stack.

Options:
  -f, --file <path>     Path to docker-compose file (default: from .env or docker/docker-compose.yml)
  -p, --project <name>  Compose project name (default: from .env or docker-env-manager)
  -b, --build           Rebuild images before starting
  -h, --help            Show this help message
EOF
}

# ---- Load config, then apply CLI overrides ------------------------------
load_env

COMPOSE_FILE="${COMPOSE_FILE:-docker/docker-compose.yml}"
PROJECT_NAME="${PROJECT_NAME:-docker-env-manager}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-60}"
BUILD_FLAG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file)
            COMPOSE_FILE="$2"
            shift 2
            ;;
        -p|--project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -b|--build)
            BUILD_FLAG="--build"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Resolve compose file relative to repo root if a relative path was given
if [[ "${COMPOSE_FILE}" != /* ]]; then
    COMPOSE_FILE="${REPO_ROOT}/${COMPOSE_FILE}"
fi

# ---- Preflight checks ----------------------------------------------------
require_docker
require_command docker

if [[ ! -f "${COMPOSE_FILE}" ]]; then
    log_error "Compose file not found: ${COMPOSE_FILE}"
    exit 1
fi

log_info "Starting stack '${PROJECT_NAME}' using ${COMPOSE_FILE}"

# ---- Start containers ----------------------------------------------------
# shellcheck disable=SC2086
if ! docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" up -d ${BUILD_FLAG}; then
    log_error "docker compose up failed"
    exit 1
fi

log_success "Containers started for project '${PROJECT_NAME}'"

# ---- Wait for healthy status ---------------------------------------------
log_info "Waiting up to ${HEALTH_TIMEOUT}s for containers to report healthy..."

elapsed=0
interval=3
while (( elapsed < HEALTH_TIMEOUT )); do
    # Containers with no healthcheck are ignored; only count ones that report "unhealthy" or "starting"
    unhealthy=$(docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" ps --format json 2>/dev/null \
        | grep -c '"Health":"unhealthy"' || true)
    starting=$(docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" ps --format json 2>/dev/null \
        | grep -c '"Health":"starting"' || true)

    if [[ "${unhealthy}" -gt 0 ]]; then
        log_error "One or more containers are unhealthy. Run './logs.sh' for details."
        exit 1
    fi

    if [[ "${starting}" -eq 0 ]]; then
        log_success "All containers are up and healthy."
        docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" ps
        exit 0
    fi

    sleep "${interval}"
    elapsed=$((elapsed + interval))
done

log_warn "Timed out after ${HEALTH_TIMEOUT}s waiting for healthy status. Current state:"
docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" ps
exit 0