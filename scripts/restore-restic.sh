#!/bin/bash
# Restic restore script for rpi5-openwebui
# Version: 1.0

set -euo pipefail

# --- Script setup ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/restore-restic.log"

mkdir -p "${LOG_DIR}"

# --- Logging functions ---
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*" | tee -a "${LOG_FILE}"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" | tee -a "${LOG_FILE}" >&2
}

log_warn() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARN: $*" | tee -a "${LOG_FILE}"
}

# --- Load configuration ---
CONFIG_FILE="${SCRIPT_DIR}/backup.config"
if [ ! -f "${CONFIG_FILE}" ]; then
    log_error "Configuration file not found: ${CONFIG_FILE}"
    exit 1
fi

# shellcheck source=scripts/backup.config
source "${CONFIG_FILE}"

# --- Load environment ---
cd "${PROJECT_ROOT}"
if [ -f ".env" ]; then
    # shellcheck source=/dev/null
    set -a
    source .env
    set +a
fi

# --- Check restic ---
if ! command -v restic &> /dev/null; then
    log_error "restic is not installed"
    exit 1
fi

# --- Restic configuration ---
export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-${RESTIC_REPO_PATH}}"
export RESTIC_PASSWORD="${RESTIC_PASSWORD}"

if [ -z "${RESTIC_PASSWORD}" ]; then
    log_error "RESTIC_PASSWORD is not set"
    exit 1
fi

# --- List snapshots ---
list_snapshots() {
    log_info "Available snapshots:"
    restic snapshots
}

# --- Restore function ---
restore_snapshot() {
    local snapshot_id="${1:-latest}"
    local target_dir="${2:-/tmp/restic-restore}"
    
    log_info "=== Starting restic restore ==="
    log_info "Snapshot: ${snapshot_id}"
    log_info "Target: ${target_dir}"
    
    # Create target directory
    mkdir -p "${target_dir}"
    
    # Confirm restore
    if [ -t 0 ]; then
        echo ""
        echo "WARNING: This will restore data to: ${target_dir}"
        echo "Snapshot: ${snapshot_id}"
        echo ""
        read -p "Continue? (yes/no): " -r confirm
        
        if [ "${confirm}" != "yes" ]; then
            log_info "Restore cancelled by user"
            exit 0
        fi
    fi
    
    # Stop containers
    log_info "Stopping Docker containers..."
    docker compose stop
    
    # Restore
    log_info "Restoring snapshot..."
    if restic restore "${snapshot_id}" \
        --target "${target_dir}" \
        --verbose=1; then
        
        log_info "Snapshot restored successfully to: ${target_dir}"
    else
        log_error "Failed to restore snapshot"
        docker compose start
        exit 1
    fi
    
    # Manual copy instructions
    log_info ""
    log_info "=== Next steps ==="
    log_info "1. Review restored files in: ${target_dir}"
    log_info "2. Manually copy needed files to project directory"
    log_info "3. For Docker volumes, use 'docker cp' or restore from extracted location"
    log_info "4. Start containers: docker compose start"
    log_info ""
    
    return 0
}

# --- Verify snapshot ---
verify_snapshot() {
    local snapshot_id="${1:-latest}"
    
    log_info "Verifying snapshot: ${snapshot_id}"
    restic diff "${snapshot_id}"
}

# --- Command handling ---
case "${1:-list}" in
    list|ls)
        list_snapshots
        ;;
    restore)
        shift
        restore_snapshot "$@"
        ;;
    verify)
        shift
        verify_snapshot "$@"
        ;;
    *)
        echo "Usage: $0 {list|restore|verify} [options]"
        echo ""
        echo "Commands:"
        echo "  list              - List all snapshots"
        echo "  restore [id] [dir] - Restore snapshot (default: latest to /tmp/restic-restore)"
        echo "  verify [id]       - Verify snapshot integrity"
        echo ""
        echo "Examples:"
        echo "  $0 list"
        echo "  $0 restore latest"
        echo "  $0 restore abc123 /tmp/my-restore"
        exit 1
        ;;
esac
