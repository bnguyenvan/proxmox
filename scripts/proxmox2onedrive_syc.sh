#!/usr/bin/env bash
# =============================================================================
# proxmox2onedrive_syc.sh — Sync Proxmox LXC backups to OneDrive
#
# What it does:
#   rclone copy *.tar.zst files from the Proxmox dump directory to OneDrive
#   under onedrive:BACKUP/<hostname>/ (only new/changed files are uploaded).
#
# Install location on the Proxmox host:
#   /usr/local/bin/proxmox2onedrive_syc.sh   (chmod 700, owned by root)
#
# Managed by systemd — see proxmox2onedrive.service / proxmox2onedrive.timer
# Check logs: journalctl -u proxmox2onedrive
# Install: cp scripts/proxmox2onedrive_syc.sh /usr/local/bin/ && chmod 700 /usr/local/bin/proxmox2onedrive_syc.sh
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SOURCE_DIR="/var/lib/vz/dump"
HOST_NAME=$(hostname)
RCLONE_REMOTE="onedrive:BACKUP/${HOST_NAME}"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
command -v rclone >/dev/null 2>&1 || { echo "ERROR: rclone not found in PATH"; exit 1; }
[ -d "$SOURCE_DIR" ] || { echo "ERROR: Source directory not found: $SOURCE_DIR"; exit 1; }

# ---------------------------------------------------------------------------
# Copy .tar.zst files to OneDrive
# ---------------------------------------------------------------------------
FILE_COUNT=$(find "$SOURCE_DIR" -maxdepth 1 -type f -name '*.tar.zst' | wc -l | tr -d ' ')
echo "===== Proxmox LXC backup sync started ====="
echo "Source : $SOURCE_DIR ($FILE_COUNT .tar.zst files)"
echo "Remote : $RCLONE_REMOTE"

if rclone copy "$SOURCE_DIR" "$RCLONE_REMOTE" \
     --include '*.tar.zst' \
     --log-level INFO \
     --stats-one-line \
     --stats 60s; then
  echo "===== Proxmox LXC backup sync finished successfully ====="
else
  EXIT_CODE=$?
  echo "ERROR: rclone exited with code $EXIT_CODE" >&2
  exit 1
fi
