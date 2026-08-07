#!/usr/bin/env bash
#
# restore.sh — Restore a Docker named volume from a .tar.gz backup created by backup.sh.
#
# Usage:
#   ./restore.sh -v|--volume <name> -i|--input <file> [-c|--clean] [-y|--yes] [-h|--help]
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
Usage: $(basename "$0") -v <volume> -i <backup-file> [OPTIONS]

Restore a Docker named volume from a .tar.gz archive produced by backup.sh.

Options:
  -v, --volume <name>   Target volume name (created automatically if it doesn't exist)
  -i, --input <file>    Path to the .tar.gz backup archive to restore
  -c, --clean           Remove the volume's existing contents before restoring
  -y, --yes             Skip the confirmation prompt
  -h, --help            Show this help message
EOF
}

# ---- Load config, then apply CLI overrides ------------------------------
load_env

VOLUME=""
INPUT_FILE=""
CLEAN_FLAG=false
ASSUME_YES=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--volume)
            VOLUME="$2"
            shift 2
            ;;
        -i|--input)
            INPUT_FILE="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN_FLAG=true
            shift
            ;;
        -y|--yes)
            ASSUME_YES=true
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

if [[ -z "${VOLUME}" || -z "${INPUT_FILE}" ]]; then
    log_error "Both -v/--volume and -i/--input are required"
    usage
    exit 1
fi

# ---- Preflight checks ----------------------------------------------------
require_docker
require_command docker

if [[ "${INPUT_FILE}" != /* ]]; then
    INPUT_FILE="${REPO_ROOT}/${INPUT_FILE}"
fi

if [[ ! -f "${INPUT_FILE}" ]]; then
    log_error "Backup file not found: ${INPUT_FILE}"
    exit 1
fi

if ! docker volume inspect "${VOLUME}" >/dev/null 2>&1; then
    log_info "Volume '${VOLUME}' does not exist yet; it will be created"
    docker volume create "${VOLUME}" >/dev/null
fi

if [[ "${ASSUME_YES}" != true ]]; then
    warning="This will restore '${INPUT_FILE}' into volume '${VOLUME}'."
    if [[ "${CLEAN_FLAG}" == true ]]; then
        warning="${warning} Its current contents will be erased first."
    fi
    log_warn "${warning}"
    read -r -p "Continue? [y/N] " confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        log_info "Aborted."
        exit 0
    fi
fi

input_dir="$(cd "$(dirname "${INPUT_FILE}")" && pwd)"
input_name="$(basename "${INPUT_FILE}")"

if [[ "${CLEAN_FLAG}" == true ]]; then
    log_info "Clearing existing contents of volume '${VOLUME}'"
    docker run --rm -v "${VOLUME}:/volume" alpine:3.20 \
        sh -c 'find /volume -mindepth 1 -delete'
fi

log_info "Restoring '${input_name}' into volume '${VOLUME}'"
docker run --rm \
    -v "${VOLUME}:/volume" \
    -v "${input_dir}:/backup:ro" \
    alpine:3.20 \
    tar xzf "/backup/${input_name}" -C /volume

log_success "Restored '${VOLUME}' from ${INPUT_FILE}"
