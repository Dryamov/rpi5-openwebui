#!/bin/bash
# Restic incremental backup script for rpi5-openwebui
# Version: 1.0

set -euo pipefail

# --- Script setup ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/backup-restic.log"

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

# --- Load environment variables ---
cd "${PROJECT_ROOT}"
if [ -f ".env" ]; then
    # shellcheck source=/dev/null
    set -a
    source .env
    set +a
else
    log_warn ".env file not found, using defaults"
fi

# --- Check if restic is enabled ---
if [ "${ENABLE_RESTIC:-false}" != "true" ]; then
    log_error "Restic is disabled in backup.config (ENABLE_RESTIC=false)"
    exit 1
fi

# --- Check restic installation ---
if ! command -v restic &> /dev/null; then
    log_error "restic is not installed. Install with: sudo apt-get install restic"
    exit 1
fi

# --- Restic configuration ---
export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-${RESTIC_REPO_PATH}}"
export RESTIC_PASSWORD="${RESTIC_PASSWORD}"

if [ -z "${RESTIC_PASSWORD}" ]; then
    log_error "RESTIC_PASSWORD is not set in .env"
    log_error "Generate one with: openssl rand -hex 32"
    exit 1
fi

# --- Initialize repository if needed ---
init_repository() {
    if ! restic snapshots &> /dev/null; then
        log_info "Restic repository not found, initializing..."
        mkdir -p "$(dirname "${RESTIC_REPOSITORY}")"
        
        if restic init; then
            log_info "Restic repository initialized at: ${RESTIC_REPOSITORY}"
        else
            log_error "Failed to initialize restic repository"
            exit 1
        fi
    else
        log_info "Restic repository exists: ${RESTIC_REPOSITORY}"
    fi
}

# --- Stop containers if configured ---
stop_containers() {
    if [ "${RESTIC_STOP_CONTAINERS:-false}" = "true" ]; then
        log_info "Stopping Docker containers for consistent backup..."
        docker compose stop
        return 0
    fi
    return 1
}

start_containers() {
    if [ "${RESTIC_STOP_CONTAINERS:-false}" = "true" ]; then
        log_info "Starting Docker containers..."
        docker compose start
    fi
}

# --- Cleanup trap ---
cleanup() {
    local exit_code=$?
    start_containers
    
    if [ $exit_code -eq 0 ]; then
        log_info "Restic backup completed successfully"
    else
        log_error "Restic backup failed with exit code: $exit_code"
    fi
    
    exit $exit_code
}

trap cleanup EXIT INT TERM

# --- Main backup function ---
backup_with_restic() {
    log_info "=== Starting restic backup ==="
    log_info "Repository: ${RESTIC_REPOSITORY}"
    
    # Initialize if needed
    init_repository
    
    # Stop containers if configured
    local containers_stopped=false
    if stop_containers; then
        containers_stopped=true
        sleep 2
    fi
    
    # Prepare backup paths
    local backup_paths=()
    
    # Add local files/directories
    for item in "${BACKUP_FILES[@]}"; do
        if [ -e "${PROJECT_ROOT}/${item}" ]; then
            backup_paths+=("${PROJECT_ROOT}/${item}")
        else
            log_warn "Backup item not found, skipping: ${item}"
        fi
    done
    
    # Add Docker volumes
    log_info "Backing up ${#BACKUP_VOLUMES[@]} Docker volumes..."
    for volume in "${BACKUP_VOLUMES[@]}"; do
        local volume_path
        volume_path=$(docker volume inspect "${volume}" --format '{{.Mountpoint}}' 2>/dev/null || true)
        
        if [ -n "${volume_path}" ]; then
            backup_paths+=("${volume_path}")
        else
            log_warn "Volume not found, skipping: ${volume}"
        fi
    done
    
    # Build exclude patterns
    local exclude_args=()
    for exclude in "${VOLUME_EXCLUDES[@]:-}"; do
        IFS=':' read -r vol_name path <<< "${exclude}"
        exclude_args+=(--exclude "${path}")
    done
    
    # Create snapshot
    log_info "Creating snapshot with ${#backup_paths[@]} paths..."
    
    local snapshot_tags=(
        --tag "auto"
        --tag "project:${PROJECT_NAME}"
        --tag "host:$(hostname)"
    )
    
    if restic backup \
        "${backup_paths[@]}" \
        "${exclude_args[@]}" \
        "${snapshot_tags[@]}" \
        --verbose=1; then
        
        log_info "Snapshot created successfully"
    else
        log_error "Failed to create snapshot"
        return 1
    fi
    
    # Apply retention policy
    log_info "Applying retention policy..."
    if restic forget \
        --keep-daily "${RESTIC_KEEP_DAILY}" \
        --keep-weekly "${RESTIC_KEEP_WEEKLY}" \
        --keep-monthly "${RESTIC_KEEP_MONTHLY}" \
        --keep-yearly "${RESTIC_KEEP_YEARLY}" \
        --prune \
        --verbose=1; then
        
        log_info "Retention policy applied"
    else
        log_warn "Failed to apply retention policy"
    fi
    
    # Show repository stats
    log_info "Repository statistics:"
    restic stats --mode raw-data | tee -a "${LOG_FILE}"
    
    # Start containers if they were stopped
    if [ "${containers_stopped}" = "true" ]; then
        start_containers
    fi
    
    return 0
}

# --- Command handling ---
case "${1:-backup}" in
    init)
        log_info "Initializing restic repository..."
        init_repository
        ;;
    backup)
        backup_with_restic
        ;;
    *)
        echo "Usage: $0 {init|backup}"
        echo "  init   - Initialize new restic repository"
        echo "  backup - Create backup snapshot (default)"
        exit 1
        ;;
esac
