#!/usr/bin/env bash
#
# health.sh — Report or wait for the health status of the Docker Compose stack.
#
# Usage:
#   ./health.sh [-f|--file <compose-file>] [-p|--project <name>] [-w|--wait] [-t|--timeout <seconds>] [-h|--help]
#
# Exits 0 if every container with a healthcheck is healthy (or none define
# one). Exits 1 if any container is unhealthy, or if --wait times out while
# containers are still starting. Intended as a standalone CI step after
# start.sh, or for manual spot-checks.
# Reads defaults from ../../.env (see .env.example), which can be overridden
# by flags on the command line.

set -euo pipefail

# ---- Load shared helpers ------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Check (or wait for) the health status of the Docker Compose stack.

Options:
  -f, --file <path>     Path to docker-compose file (default: from .env or docker/docker-compose.yml)
  -p, --project <name>  Compose project name (default: from .env or docker-env-manager)
  -w, --wait            Wait out containers still reporting "starting" instead of failing immediately
  -t, --timeout <secs>  Max seconds to wait when --wait is set (default: 60)
  -h, --help            Show this help message
EOF
}

# ---- Load config, then apply CLI overrides ------------------------------
load_env

COMPOSE_FILE="${COMPOSE_FILE:-docker/docker-compose.yml}"
PROJECT_NAME="${PROJECT_NAME:-docker-env-manager}"
WAIT_FLAG=false
TIMEOUT="${HEALTH_TIMEOUT:-60}"

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
        -w|--wait)
            WAIT_FLAG=true
            shift
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
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

# Prints "<unhealthy_count> <starting_count>". Containers with no
# healthcheck defined report no "Health" field at all and are ignored.
check_once() {
    local ps_json unhealthy starting
    ps_json="$(docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" ps --format json 2>/dev/null || true)"
    unhealthy="$(grep -c '"Health":"unhealthy"' <<< "${ps_json}" || true)"
    starting="$(grep -c '"Health":"starting"' <<< "${ps_json}" || true)"
    echo "${unhealthy} ${starting}"
}

log_info "Checking health for '${PROJECT_NAME}'"

elapsed=0
interval=3
while true; do
    read -r unhealthy starting < <(check_once)

    if [[ "${unhealthy}" -gt 0 ]]; then
        log_error "${unhealthy} container(s) unhealthy."
        docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" ps
        exit 1
    fi

    if [[ "${starting}" -eq 0 ]]; then
        log_success "All containers are up and healthy."
        docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" ps
        exit 0
    fi

    if [[ "${WAIT_FLAG}" != true ]]; then
        log_warn "${starting} container(s) still starting (use --wait to wait it out)."
        docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" ps
        exit 1
    fi

    if (( elapsed >= TIMEOUT )); then
        log_error "Timed out after ${TIMEOUT}s waiting for healthy status."
        docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" ps
        exit 1
    fi

    sleep "${interval}"
    elapsed=$((elapsed + interval))
done
