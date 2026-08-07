#!/usr/bin/env bash
#
# stop.sh — Stop the Docker Compose stack for this project.
#
# Usage:
#   ./stop.sh [-f|--file <compose-file>] [-p|--project <name>] [-v|--volumes] [-h|--help]
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

Stop the Docker Compose stack.

Options:
  -f, --file <path>     Path to docker-compose file (default: from .env or docker/docker-compose.yml)
  -p, --project <name>  Compose project name (default: from .env or docker-env-manager)
  -v, --volumes         Also remove named volumes declared in the compose file
  -h, --help            Show this help message
EOF
}

# ---- Load config, then apply CLI overrides ------------------------------
load_env

COMPOSE_FILE="${COMPOSE_FILE:-docker/docker-compose.yml}"
PROJECT_NAME="${PROJECT_NAME:-docker-env-manager}"
VOLUMES_FLAG=""

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
        -v|--volumes)
            VOLUMES_FLAG="--volumes"
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

log_info "Stopping stack '${PROJECT_NAME}' using ${COMPOSE_FILE}"

if [[ -n "${VOLUMES_FLAG}" ]]; then
    log_warn "Named volumes for '${PROJECT_NAME}' will be removed"
fi

# ---- Stop containers ------------------------------------------------------
# shellcheck disable=SC2086
if ! docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" down ${VOLUMES_FLAG}; then
    log_error "docker compose down failed"
    exit 1
fi

log_success "Stack '${PROJECT_NAME}' stopped."