#!/usr/bin/env bash
#
# backup.sh — Back up Docker named volumes to compressed tarballs.
#
# Usage:
#   ./backup.sh [-p|--project <name>] [-v|--volume <name>]... [-o|--output <dir>] [-h|--help]
#
# With no -v/--volume flags, backs up every volume Docker Compose tagged
# with this project's label (com.docker.compose.project=<name>). Each
# volume is streamed through a throwaway alpine container so no host
# mount permissions are required.
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

Back up Docker named volumes to timestamped .tar.gz archives.

Options:
  -p, --project <name>  Compose project name used to auto-discover volumes (default: from .env or docker-env-manager)
  -v, --volume <name>   Back up a specific volume (repeatable). Overrides project auto-discovery.
  -o, --output <dir>    Directory to write backups to (default: ./backups)
  -h, --help            Show this help message
EOF
}

# ---- Load config, then apply CLI overrides ------------------------------
load_env

PROJECT_NAME="${PROJECT_NAME:-docker-env-manager}"
OUTPUT_DIR="${BACKUP_DIR:-${REPO_ROOT}/backups}"
VOLUMES=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -v|--volume)
            VOLUMES+=("$2")
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
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

# ---- Preflight checks ----------------------------------------------------
require_docker
require_command docker

if [[ "${OUTPUT_DIR}" != /* ]]; then
    OUTPUT_DIR="${REPO_ROOT}/${OUTPUT_DIR}"
fi
mkdir -p "${OUTPUT_DIR}"

# ---- Discover volumes if none were given explicitly -----------------------
if [[ "${#VOLUMES[@]}" -eq 0 ]]; then
    log_info "Discovering volumes for project '${PROJECT_NAME}'"
    while IFS= read -r vol; do
        [[ -n "${vol}" ]] && VOLUMES+=("${vol}")
    done < <(docker volume ls -q -f "label=com.docker.compose.project=${PROJECT_NAME}")
fi

if [[ "${#VOLUMES[@]}" -eq 0 ]]; then
    log_error "No volumes found for project '${PROJECT_NAME}'. Use -v to specify one explicitly."
    exit 1
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
failures=0

for volume in "${VOLUMES[@]}"; do
    if ! docker volume inspect "${volume}" >/dev/null 2>&1; then
        log_error "Volume not found: ${volume}"
        failures=$((failures + 1))
        continue
    fi

    archive_name="${volume}-${timestamp}.tar.gz"
    log_info "Backing up volume '${volume}' -> ${OUTPUT_DIR}/${archive_name}"

    if docker run --rm \
        -v "${volume}:/volume:ro" \
        -v "${OUTPUT_DIR}:/backup" \
        alpine:3.20 \
        tar czf "/backup/${archive_name}" -C /volume .; then
        log_success "Backed up '${volume}'"
    else
        log_error "Failed to back up '${volume}'"
        failures=$((failures + 1))
    fi
done

if [[ "${failures}" -gt 0 ]]; then
    log_error "${failures} volume(s) failed to back up."
    exit 1
fi

log_success "All volumes backed up to ${OUTPUT_DIR}"
