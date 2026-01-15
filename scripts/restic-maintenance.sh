#!/bin/bash
# Restic maintenance and management script
# Version: 1.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- Load environment ---
cd "${PROJECT_ROOT}"
if [ -f ".env" ]; then
    # shellcheck source=/dev/null
    set -a
    source .env
    set +a
fi

# --- Restic configuration ---
export RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-/backups/restic-repo}"
export RESTIC_PASSWORD="${RESTIC_PASSWORD}"

if [ -z "${RESTIC_PASSWORD}" ]; then
    echo "ERROR: RESTIC_PASSWORD is not set"
    exit 1
fi

if ! command -v restic &> /dev/null; then
    echo "ERROR: restic is not installed"
    exit 1
fi

# --- Commands ---
show_stats() {
    echo "=== Repository Statistics ==="
    restic stats --mode raw-data
    echo ""
    echo "=== Storage Summary ==="
    restic stats --mode restore-size
}

list_snapshots() {
    echo "=== All Snapshots ==="
    restic snapshots
}

check_repository() {
    echo "=== Checking Repository Integrity ==="
    restic check --read-data-subset=5%
}

prune_repository() {
    echo "=== Pruning Repository ==="
    echo "This will remove old snapshots according to retention policy..."
    
    # shellcheck source=scripts/backup.config
    source "${SCRIPT_DIR}/backup.config"
    
    restic forget \
        --keep-daily "${RESTIC_KEEP_DAILY:-7}" \
        --keep-weekly "${RESTIC_KEEP_WEEKLY:-4}" \
        --keep-monthly "${RESTIC_KEEP_MONTHLY:-6}" \
        --keep-yearly "${RESTIC_KEEP_YEARLY:-2}" \
        --prune \
        --verbose
}

unlock_repository() {
    echo "=== Unlocking Repository ==="
    restic unlock
}

show_snapshot() {
    local snapshot_id="${1:-latest}"
    echo "=== Snapshot Details: ${snapshot_id} ==="
    restic snapshots "${snapshot_id}"
    echo ""
    echo "=== Snapshot Contents ==="
    restic ls "${snapshot_id}" | head -50
}

# --- Help ---
show_help() {
    cat << EOF
Restic Maintenance Tool

Usage: $0 <command> [options]

Commands:
  stats       - Show repository statistics
  list        - List all snapshots
  check       - Check repository integrity
  prune       - Apply retention policy and prune old data
  unlock      - Unlock repository (if locked)
  show [id]   - Show snapshot details (default: latest)
  help        - Show this help

Examples:
  $0 stats
  $0 list
  $0 check
  $0 prune
  $0 show latest
  $0 show abc123

Repository: ${RESTIC_REPOSITORY}
EOF
}

# --- Main ---
case "${1:-help}" in
    stats)
        show_stats
        ;;
    list|ls)
        list_snapshots
        ;;
    check)
        check_repository
        ;;
    prune)
        prune_repository
        ;;
    unlock)
        unlock_repository
        ;;
    show)
        shift
        show_snapshot "$@"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run '$0 help' for usage"
        exit 1
        ;;
esac
