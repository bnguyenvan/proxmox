#!/usr/bin/env bash
# =============================================================================
# proxmox-bisync.sh — Two-way sync of LXC dump files between Proxmox nodes
#
# What it does:
#   rclone bisync /var/lib/vz/dump/ on this node with the same directory on
#   the remote Proxmox node (configured as an rclone SFTP remote).
#   Only *.tar.zst files are considered.
#
# Prerequisites:
#   - rclone configured with an SFTP remote named PROXMOX_REMOTE (see below)
#     Run once: rclone config  → add remote → SFTP → <other-node-ip> → root
#   - SSH key-based auth between the two nodes (no password prompt)
#
# First-run (initialises bisync state files):
#   /usr/local/bin/proxmox-bisync.sh --resync
#
# Install location on the Proxmox host:
#   /usr/local/bin/proxmox-bisync.sh   (chmod 700, owned by root)
#
# Managed by systemd — see proxmox-bisync.service / proxmox-bisync.timer
# Check logs: journalctl -u proxmox-bisync
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
LOCAL_DIR="/var/lib/vz/dump"
# Name of the rclone remote pointing to the other Proxmox node (SFTP)
PROXMOX_REMOTE="proxmox-secondary"
REMOTE_DIR="${PROXMOX_REMOTE}:/var/lib/vz/dump"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
command -v rclone >/dev/null 2>&1 || { echo "ERROR: rclone not found in PATH"; exit 1; }
[ -d "$LOCAL_DIR" ] || { echo "ERROR: Local dump directory not found: $LOCAL_DIR"; exit 1; }

rclone listremotes | grep -q "^${PROXMOX_REMOTE}:" \
  || { echo "ERROR: rclone remote '${PROXMOX_REMOTE}' not configured. Run: rclone config"; exit 1; }

# ---------------------------------------------------------------------------
# Build rclone arguments
# ---------------------------------------------------------------------------
RCLONE_ARGS=(
  bisync
  "$LOCAL_DIR"
  "$REMOTE_DIR"
  --include '*.tar.zst'
  --log-level INFO
  --stats-one-line
  --stats 60s
  --conflict-resolve newer        # keep the newer file on conflict
  --conflict-loser num            # rename the loser instead of deleting
)

# Pass --resync on first run to initialise bisync state files
if [[ "${1:-}" == "--resync" ]]; then
  RCLONE_ARGS+=(--resync)
  echo "INFO: Running with --resync (first-run mode)"
fi

# ---------------------------------------------------------------------------
# Run bisync
# ---------------------------------------------------------------------------
echo "===== Proxmox bisync started ====="
echo "Local  : $LOCAL_DIR"
echo "Remote : $REMOTE_DIR"

if rclone "${RCLONE_ARGS[@]}"; then
  echo "===== Proxmox bisync finished successfully ====="
else
  EXIT_CODE=$?
  echo "ERROR: rclone bisync exited with code $EXIT_CODE" >&2
  exit 1
fi
