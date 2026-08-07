#!/usr/bin/env bash
#
# logs.sh — View or tail logs for the Docker Compose stack.
#
# Usage:
#   ./logs.sh [-f|--file <compose-file>] [-p|--project <name>] [-s|--service <name>] [-n|--tail <lines>] [--follow] [-h|--help] [SERVICE]
#
# Reads defaults from ../../.env (see .env.example), which can be overridden
# by flags on the command line.

set -euo pipefail

# ---- Load shared helpers ------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [SERVICE]

View logs for the Docker Compose stack.

Options:
  -f, --file <path>     Path to docker-compose file (default: from .env or docker/docker-compose.yml)
  -p, --project <name>  Compose project name (default: from .env or docker-env-manager)
  -s, --service <name>  Only show logs for this service (can also be given positionally)
      --follow          Stream logs continuously (like tail -f)
  -n, --tail <lines>    Number of lines to show from the end (default: 100)
  -h, --help            Show this help message
EOF
}

# ---- Load config, then apply CLI overrides ------------------------------
load_env

COMPOSE_FILE="${COMPOSE_FILE:-docker/docker-compose.yml}"
PROJECT_NAME="${PROJECT_NAME:-docker-env-manager}"
SERVICE=""
TAIL_LINES="100"
FOLLOW_FLAG=""

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
        -s|--service)
            SERVICE="$2"
            shift 2
            ;;
        --follow)
            FOLLOW_FLAG="--follow"
            shift
            ;;
        -n|--tail)
            TAIL_LINES="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            # Allow a bare positional service name too: ./logs.sh airflow-scheduler
            SERVICE="$1"
            shift
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

log_info "Showing logs for '${PROJECT_NAME}'${SERVICE:+ (service: ${SERVICE})}"

# shellcheck disable=SC2086
docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" logs --tail "${TAIL_LINES}" ${FOLLOW_FLAG} ${SERVICE}
