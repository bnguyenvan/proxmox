#!/usr/bin/env bash
# =============================================================================
# backup-photos.sh — Incremental photo backup for the Pharmacy POS system
#
# What it does:
#   rclone sync the Rails Active Storage folder to OneDrive (incremental —
#   only new/changed files are uploaded; files deleted locally are NOT deleted
#   from OneDrive unless --delete-during is added intentionally).
#
# Install location on the app server (192.168.31.102):
#   /usr/local/bin/backup-photos.sh   (chmod 700, owned by root)
#
# Managed by systemd — see backup-photos.service / backup-photos.timer
# Check logs: journalctl -u backup-photos
# Install: cp scripts/backup-photos.sh /usr/local/bin/ && chmod 700 /usr/local/bin/backup-photos.sh
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SOURCE_DIR="/var/www/pharmacy_backend/shared/storage"
RCLONE_REMOTE="onedrive:BACKUP/PharmacyPos/pharmacy-app/storage/192.168.31.102"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
command -v rclone >/dev/null 2>&1 || { echo "ERROR: rclone not found in PATH" >&2; exit 1; }
[ -d "$SOURCE_DIR" ] || { echo "ERROR: Source directory not found: $SOURCE_DIR" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Sync to OneDrive
# ---------------------------------------------------------------------------
FILE_COUNT=$(find "$SOURCE_DIR" -type f | wc -l | tr -d ' ')
echo "===== Photo backup started ====="
echo "Source : $SOURCE_DIR ($FILE_COUNT files)"
echo "Remote : $RCLONE_REMOTE"

if rclone sync "$SOURCE_DIR" "$RCLONE_REMOTE" \
     --log-level INFO \
     --stats-one-line \
     --stats 60s; then
  echo "===== Photo backup finished successfully ====="
else
  EXIT_CODE=$?
  echo "ERROR: rclone exited with code $EXIT_CODE" >&2
  exit 1
fi
