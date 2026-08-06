#!/usr/bin/env bash
# common.sh — shared logging + config helpers for all Docker Environment Manager scripts.
# Source this from every script:  source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

# ---- Paths -------------------------------------------------------------
# Resolve repo root relative to this file, so scripts work no matter where
# they're invoked from.
COMMON_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${COMMON_LIB_DIR}/../../.." && pwd)"
LOG_DIR="${REPO_ROOT}/logs"
LOG_FILE="${LOG_DIR}/docker-env-manager.log"

mkdir -p "${LOG_DIR}"

# ---- Logging -------------------------------------------------------------
# Every log line goes to stdout/stderr (colored) AND to LOG_FILE (plain),
# so CI output and local history both stay useful.

_ts() { date '+%Y-%m-%d %H:%M:%S'; }

log_info() {
    local msg="$1"
    printf '\033[1;34m[INFO]\033[0m  %s  %s\n' "$(_ts)" "$msg"
    printf '[INFO]  %s  %s\n' "$(_ts)" "$msg" >> "${LOG_FILE}"
}

log_warn() {
    local msg="$1"
    printf '\033[1;33m[WARN]\033[0m  %s  %s\n' "$(_ts)" "$msg"
    printf '[WARN]  %s  %s\n' "$(_ts)" "$msg" >> "${LOG_FILE}"
}

log_error() {
    local msg="$1"
    printf '\033[1;31m[ERROR]\033[0m %s  %s\n' "$(_ts)" "$msg" >&2
    printf '[ERROR] %s  %s\n' "$(_ts)" "$msg" >> "${LOG_FILE}"
}

log_success() {
    local msg="$1"
    printf '\033[1;32m[ OK ]\033[0m  %s  %s\n' "$(_ts)" "$msg"
    printf '[ OK ]  %s  %s\n' "$(_ts)" "$msg" >> "${LOG_FILE}"
}

# ---- Config loading --------------------------------------------------
# Loads REPO_ROOT/.env if present. Does not error if it's missing —
# scripts should define sane defaults after calling this.
load_env() {
    local env_file="${REPO_ROOT}/.env"
    if [[ -f "${env_file}" ]]; then
        set -a
        # shellcheck disable=SC1090
        source "${env_file}"
        set +a
        log_info "Loaded config from ${env_file}"
    else
        log_warn "No .env file found at ${env_file} — using defaults"
    fi
}

# ---- Preflight checks --------------------------------------------------
require_command() {
    local cmd="$1"
    if ! command -v "${cmd}" &> /dev/null; then
        log_error "Required command '${cmd}' not found in PATH. Please install it and retry."
        exit 1
    fi
}

require_docker() {
    require_command docker
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running or not accessible."
        exit 1
    fi
}