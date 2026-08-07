#!/usr/bin/env bash
#
# cleanup.sh — Clean up Docker resources for this project (and optionally the host).
#
# Usage:
#   ./cleanup.sh [-f|--file <compose-file>] [-p|--project <name>] [-a|--all] [-v|--volumes] [-n|--dry-run] [-h|--help]
#
# By default, only removes this project's stopped/orphaned containers and
# dangling images. Use --all for a broader host-wide `docker system prune`.
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

Clean up Docker resources.

Options:
  -f, --file <path>     Path to docker-compose file (default: from .env or docker/docker-compose.yml)
  -p, --project <name>  Compose project name (default: from .env or docker-env-manager)
  -a, --all             Also run a host-wide 'docker system prune' (images, build cache, networks)
  -v, --volumes         Also remove this project's named volumes (DESTRUCTIVE)
  -n, --dry-run         Show what would be removed without removing anything
  -h, --help            Show this help message
EOF
}

# ---- Load config, then apply CLI overrides ------------------------------
load_env

COMPOSE_FILE="${COMPOSE_FILE:-docker/docker-compose.yml}"
PROJECT_NAME="${PROJECT_NAME:-docker-env-manager}"
ALL_FLAG=false
VOLUMES_FLAG=false
DRY_RUN=false

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
        -a|--all)
            ALL_FLAG=true
            shift
            ;;
        -v|--volumes)
            VOLUMES_FLAG=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
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

if [[ "${DRY_RUN}" == true ]]; then
    log_warn "Dry run: no resources will be removed"
fi

# ---- Project-scoped cleanup ------------------------------------------------
if [[ -f "${COMPOSE_FILE}" ]]; then
    log_info "Removing stopped/orphaned containers for project '${PROJECT_NAME}'"
    if [[ "${DRY_RUN}" == true ]]; then
        docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" ps -a
    else
        down_args=(--remove-orphans)
        if [[ "${VOLUMES_FLAG}" == true ]]; then
            log_warn "Named volumes for '${PROJECT_NAME}' will be removed"
            down_args+=(--volumes)
        fi
        docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" down "${down_args[@]}"
    fi
else
    log_warn "Compose file not found: ${COMPOSE_FILE} — skipping project-scoped cleanup"
fi

log_info "Removing dangling images"
dangling_ids="$(docker images -f "dangling=true" -q)"
if [[ -n "${dangling_ids}" ]]; then
    if [[ "${DRY_RUN}" == true ]]; then
        docker images -f "dangling=true"
    else
        # shellcheck disable=SC2086
        docker rmi ${dangling_ids} 2>/dev/null || log_warn "Some dangling images could not be removed (still in use)"
    fi
else
    log_info "No dangling images found"
fi

# ---- Host-wide cleanup ------------------------------------------------
if [[ "${ALL_FLAG}" == true ]]; then
    log_info "Running host-wide docker system prune"
    prune_args=(--force)
    if [[ "${VOLUMES_FLAG}" == true ]]; then
        prune_args+=(--volumes)
    fi
    if [[ "${DRY_RUN}" == true ]]; then
        log_info "(dry run) Would run: docker system prune ${prune_args[*]}"
        docker system df
    else
        docker system prune "${prune_args[@]}"
    fi
fi

log_success "Cleanup complete."
