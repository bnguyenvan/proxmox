#!/usr/bin/env bash
# =============================================================================
# pg_backup.sh — PostgreSQL nightly backup for the Pharmacy POS system
#
# What it does:
#   1. pg_dump each database → gzip → /var/backups/postgresql/
#   2. Delete local backup files older than RETAIN_DAYS days
#   3. rclone copy the local backup folder to OneDrive
#
# Install location on the DB server (192.168.31.101):
#   /usr/local/bin/pg_backup.sh   (chmod 700, owned by root)
#
# Managed by systemd — see backup-database.service / backup-database.timer
# Check logs: journalctl -u backup-database
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PG_USER="postgres"
BACKUP_DIR="/var/backups/postgresql"
RETAIN_DAYS=10
RCLONE_REMOTE="onedrive:BACKUP/PharmacyPos/pharmacy-db/192.168.31.101"

DATABASES=(
  "pharmacy_production"
)

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
mkdir -p "$BACKUP_DIR" || { echo "ERROR: Cannot create backup directory: $BACKUP_DIR" >&2; exit 1; }
command -v pg_dump  >/dev/null 2>&1 || { echo "ERROR: pg_dump not found in PATH" >&2; exit 1; }
command -v gzip     >/dev/null 2>&1 || { echo "ERROR: gzip not found in PATH" >&2; exit 1; }
command -v rclone   >/dev/null 2>&1 || { echo "ERROR: rclone not found in PATH" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Backup each database
# ---------------------------------------------------------------------------
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
ERRORS=0

echo "===== Backup started (timestamp: $TIMESTAMP) ====="

for DB in "${DATABASES[@]}"; do
  FILENAME="${DB}_${TIMESTAMP}.sql.gz"
  DEST="${BACKUP_DIR}/${FILENAME}"

  echo "Dumping $DB → $DEST"
  if sudo -u postgres pg_dump -U "$PG_USER" "$DB" | gzip -9 > "$DEST"; then
    SIZE=$(du -sh "$DEST" | cut -f1)
    echo "  OK  $FILENAME ($SIZE)"
  else
    echo "ERROR: $DB — dump failed" >&2
    rm -f "$DEST"   # remove partial file
    ERRORS=$((ERRORS + 1))
  fi
done

# ---------------------------------------------------------------------------
# Purge old backups
# ---------------------------------------------------------------------------
echo "Purging backups older than ${RETAIN_DAYS} days from $BACKUP_DIR"
find "$BACKUP_DIR" -maxdepth 1 -name "*.sql.gz" \
  -mtime +"$RETAIN_DAYS" -print -delete | while read -r f; do
  echo "  Deleted: $(basename "$f")"
done

# ---------------------------------------------------------------------------
# Upload to OneDrive via rclone
# ---------------------------------------------------------------------------
echo "Uploading $BACKUP_DIR → $RCLONE_REMOTE"
if rclone copy "$BACKUP_DIR" "$RCLONE_REMOTE" \
     --log-level INFO; then
  echo "  rclone upload complete"
else
  echo "ERROR: rclone upload failed (exit $?)" >&2
  ERRORS=$((ERRORS + 1))
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [ "$ERRORS" -eq 0 ]; then
  echo "===== Backup finished successfully ====="
else
  echo "ERROR: Backup finished with $ERRORS error(s)" >&2
  exit 1
fi
