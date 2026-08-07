#!/usr/bin/env bash
#
# restart.sh — Restart the Docker Compose stack for this project.
#
# Usage:
#   ./restart.sh [-f|--file <compose-file>] [-p|--project <name>] [-b|--build] [-h|--help]
#
# Equivalent to running stop.sh followed by start.sh with the same flags.
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

Restart the Docker Compose stack (stop, then start).

Options:
  -f, --file <path>     Path to docker-compose file (default: from .env or docker/docker-compose.yml)
  -p, --project <name>  Compose project name (default: from .env or docker-env-manager)
  -b, --build           Rebuild images before starting back up
  -h, --help            Show this help message
EOF
}

# ---- Load config, then apply CLI overrides ------------------------------
load_env

COMPOSE_FILE="${COMPOSE_FILE:-docker/docker-compose.yml}"
PROJECT_NAME="${PROJECT_NAME:-docker-env-manager}"
BUILD_FLAG=()

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
            BUILD_FLAG=(--build)
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

# ---- Preflight checks ----------------------------------------------------
require_docker
require_command docker

log_info "Restarting stack '${PROJECT_NAME}'"

# ---- Stop, then start -----------------------------------------------------
# Each child script resolves COMPOSE_FILE relative to REPO_ROOT itself, so
# pass it through as-received rather than resolving it twice.
"${SCRIPT_DIR}/stop.sh" -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}"
"${SCRIPT_DIR}/start.sh" -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" "${BUILD_FLAG[@]}"

log_success "Stack '${PROJECT_NAME}' restarted."
