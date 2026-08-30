# Proxmox VE Maintenance Runbook & Best Practices

A complete operational guide for maintaining, updating, and optimizing the Proxmox Virtual Environment (PVE) cluster/nodes.

---

## Table of Contents

1. [Node Inventory & System Overview](#1-node-inventory--system-overview)
2. [Monthly Proxmox VE Update & Patching Procedure](#2-monthly-proxmox-ve-update--patching-procedure)
   - [2a. Pre-Update Health Check](#2a-pre-update-health-check)
   - [2b. Repository Configuration (No-Subscription)](#2b-repository-configuration-no-subscription)
   - [2c. Performing the System Update](#2c-performing-the-system-update)
   - [2d. Kernel Upgrade & Graceful Reboot Orchestration](#2d-kernel-upgrade--graceful-reboot-orchestration)
3. [Storage & Hardware Health Monitoring](#3-storage--hardware-health-monitoring)
   - [3a. NVMe & SSD SMART Wearout Checks](#3a-nvme--ssd-smart-wearout-checks)
   - [3b. ZFS Pool Health & Monthly Scrubbing](#3b-zfs-pool-health--monthly-scrubbing)
   - [3c. LVM-Thin Pool & Storage Space Audit](#3c-lvm-thin-pool--storage-space-audit)
   - [3d. Storage TRIM Execution](#3d-storage-trim-execution)
4. [System Log & Disk Space Maintenance](#4-system-log--disk-space-maintenance)
   - [4a. Journald & Log Vacuuming](#4a-journald--log-vacuuming)
   - [4b. Temp Files & Core Dump Cleanup](#4b-temp-files--core-dump-cleanup)
5. [Backup Verification & Restore Drill](#5-backup-verification--restore-drill)
   - [5a. Proxmox VZDump Backup Job Audit (`n150`)](#5a-proxmox-vzdump-backup-job-audit-n150)
   - [5b. OneDrive Offsite Backup Sync (rclone)](#5b-onedrive-offsite-backup-sync-rclone)
   - [5c. Secondary Node Transfer Check (`n150` → `n100`)](#5c-secondarydr-node-transfer-check-n150--n100)
   - [5d. Monthly Test Restoration Drill](#5d-monthly-test-restoration-drill)
6. [Security & Access Control Audit](#6-security--access-control-audit)
   - [6a. SSH & Authentication Hardening Audit](#6a-ssh--authentication-hardening-audit)
   - [6b. Proxmox Firewall & Network Status](#6b-proxmox-firewall--network-status)
   - [6c. SSL Certificate & ACME Renewal Check](#6c-ssl-certificate--acme-renewal-check)
7. [Guest (VM & LXC) Maintenance Routine](#7-guest-vm--lxc-maintenance-routine)
   - [7a. Guest OS Updating](#7a-guest-os-updating)
   - [7b. QEMU Guest Agent & VirtIO Drivers Check](#7b-qemu-guest-agent--virtio-drivers-check)
   - [7c. Stale Snapshot Cleanup](#7c-stale-snapshot-cleanup)
8. [Monthly Maintenance Checklist](#8-monthly-maintenance-checklist)

---

## 1. Node Inventory & System Overview

> **Proxmox VE Version:** 9
> **Credentials:** stored in Bitwarden

| Node Name  | Hostname | CPU        | IP Address      | Web GUI                                                  | Role                | Primary Tasks / Workloads                                                                                     |
| ---------- | -------- | ---------- | --------------- | -------------------------------------------------------- | ------------------- | ------------------------------------------------------------------------------------------------------------- |
| **`n100`** | `pve`    | Intel N100 | `192.168.31.10` | [n100.ducloi6.dpdns.org](https://n100.ducloi6.dpdns.org) | Primary PVE Node    | Primary OPNsense. Pharmacy POS & Backend (migration target).<br>Daily automated Proxmox Backup Job (`22:45`). |
| **`n150`** | `n150`   | Intel N150 | `192.168.31.30` | [n150.ducloi6.dpdns.org](https://n150.ducloi6.dpdns.org) | Secondary / DR Node | Standby Disaster Recovery Host & Backup Archive Target.                                                       |

---

## 2. Monthly Proxmox VE Update & Patching Procedure

Update nodes sequentially — `n100` first, then `n150`.

### 2a. Pre-Update Health Check

```bash
df -h / /var /var/lib/vz   # ensure disks are not near full
ping -c 3 1.1.1.1           # verify internet connectivity
```

### 2b. Repository Configuration (No-Subscription)

Ensure `/etc/apt/sources.list.d/pve-enterprise.list` has the enterprise line **commented out**, and `/etc/apt/sources.list.d/pve-no-subscription.list` contains:

```apt
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
```

### 2c. Update

```bash
apt update && apt-get dist-upgrade -y
```

> ⚠️ Always use `apt-get dist-upgrade`, not `apt upgrade`.

### 2d. Reboot (if kernel updated)

```bash
# Check if a new kernel was installed
uname -r
dpkg -l | grep -E "proxmox-kernel|pve-kernel" | grep "^ii" | tail -n 3

# Stop containers before rebooting
pct stop 102    # n150 only — Pharmacy POS container

systemctl reboot

# After reboot: verify services and restart containers
systemctl status pvedaemon pveproxy pvestatd
pct start 102
```

---

## 3. Storage & Hardware Health Monitoring

### 3a. NVMe & SSD SMART Wearout Checks

Inspect drive health and wearout levels monthly to replace failing drives before data loss occurs.

```bash
# Install smartmontools & nvme-cli if missing
apt install -y smartmontools nvme-cli

# List all storage devices
lsblk

# Check NVMe Health & Wearout Percentage
nvme smart-log /dev/nvme0n1

# Check SATA SSD / HDD SMART Status
smartctl -H /dev/sda
smartctl -A /dev/sda | grep -i wear
```

#### Health Threshold Alert Indicators

| Metric                                                   | Indicator   | Action Threshold                     |
| -------------------------------------------------------- | ----------- | ------------------------------------ |
| NVMe `percentage_used`                                   | Wearout %   | > 80% → Plan drive replacement       |
| SATA SSD `Wearout_Indicator` / `Media_Wearout_Indicator` | Wear level  | < 20% remaining → Plan replacement   |
| SMART `overall-health`                                   | Test result | `FAILED` → Replace drive immediately |

---

### 3b. ZFS Pool Health & Monthly Scrubbing

If using ZFS storage pools (`rpool` or custom zpools):

```bash
# 1. Check pool status and errors
zpool status -x

# 2. Run monthly pool scrub (integrity check)
zpool scrub rpool

# 3. Monitor scrub progress
zpool status rpool
```

> 💡 **Tip:** Add a monthly cron job for ZFS scrubbing if not configured automatically:
> `0 2 1 * * /sbin/zpool scrub rpool`

---

### 3c. LVM-Thin Pool & Storage Space Audit

If using LVM-Thin storage:

```bash
# Check volume group and thin pool metadata/data usage
pvs
vgs
lvs -a
```

> ⚠️ **Warning:** LVM-Thin pools must never reach 100% data or metadata usage. If thin pool usage exceeds 85%, extend the pool or delete unused disk images.

---

### 3d. Storage TRIM Execution

Run `fstrim` to discard unused blocks on SSDs/NVMe drives:

```bash
# Trim all mounted filesystems that support it
fstrim -av
```

Enable the systemd trim timer if not already active:

```bash
systemctl enable --now fstrim.timer
systemctl status fstrim.timer
```

---

## 4. System Log & Disk Space Maintenance

### 4a. Journald & Log Vacuuming

Prevent `/var/log/journal` from consuming excessive root partition space.

```bash
# Check log disk usage
du -sh /var/log/journal

# Vacuum journal logs older than 14 days
journalctl --vacuum-time=14d

# Limit total journal log size to 1 GB
journalctl --vacuum-size=1G
```

#### Permanent Journal Size Limit

Edit `/etc/systemd/journald.conf`:

```ini
[Journal]
SystemMaxUse=1G
SystemMaxFileSize=128M
MaxRetentionSec=1month
```

Apply settings:

```bash
systemctl restart systemd-journald
```

---

### 4b. Temp Files & Core Dump Cleanup

```bash
# Remove old task logs older than 30 days
find /var/log/pve/tasks/ -type f -mtime +30 -delete

# Check for core dumps
ls -lh /var/lib/systemd/coredump/
rm -f /var/lib/systemd/coredump/*
```

---

## 5. Backup Verification & Restore Drill

### 5a. Proxmox VZDump Backup Job Audit (`n150`)

Verify that the daily backup job scheduled on `n150` (`22:45`) is completing cleanly:

```bash
# Inspect VZDump log files
ls -lt /var/log/vzdump/ | head -n 5
tail -n 20 /var/log/vzdump/vzdump-lxc-102-*.log
```

---

### 5b. OneDrive Offsite Backup Sync (rclone)

LXC dump files (`*.tar.zst`) from `/var/lib/vz/dump/` are synced to `onedrive:BACKUP/<hostname>/` via rclone, managed by a systemd service and timer. Runs daily at **03:00**.

#### Deployed Files

| File                       | Host Path                                      |
| -------------------------- | ---------------------------------------------- |
| `proxmox2onedrive_syc.sh`  | `/usr/local/bin/proxmox2onedrive_syc.sh`       |
| `proxmox2onedrive.service` | `/etc/systemd/system/proxmox2onedrive.service` |
| `proxmox2onedrive.timer`   | `/etc/systemd/system/proxmox2onedrive.timer`   |

#### Initial Deployment

```bash
cp scripts/proxmox2onedrive_syc.sh /usr/local/bin/
chmod 700 /usr/local/bin/proxmox2onedrive_syc.sh
cp scripts/proxmox2onedrive.{service,timer} /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now proxmox2onedrive.timer
```

#### Verification

```bash
# Check timer status and next scheduled run
systemctl status proxmox2onedrive.timer

# View sync logs
journalctl -u proxmox2onedrive

# Manually trigger a sync
systemctl start proxmox2onedrive.service
```

---

### 5c. Secondary/DR Node Transfer Check (`n150` → `n100`)

Ensure backups are being transferred from `n150` to `n100`:

```bash
# Verify latest backup file present on n100
ssh root@n100 "ls -lh /var/lib/vz/dump/"
```

---

### 5d. Monthly Test Restoration Drill

Perform a monthly dry-run restore of the Application LXC Container (`102`) onto node `n100` under a test VMID (e.g., `999`):

```bash
# 1. Run restore under test ID 999 on n100
pct restore 999 /var/lib/vz/dump/vzdump-lxc-102-*.tar.zst --storage local-lvm

# 2. Start test container (isolated network recommended)
pct start 999

# 3. Test application health inside test container
pct exec 999 -- curl -I http://localhost/health

# 4. Cleanup test container after drill
pct stop 999
pct destroy 999
```

---

## 6. Security & Access Control Audit

### 6a. SSH & Authentication Hardening Audit

```bash
# 1. Verify root password login settings in SSH
grep -i "PermitRootLogin" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*

# 2. Check for unauthorized SSH keys
cat /root/.ssh/authorized_keys

# 3. Inspect failed authentication attempts
journalctl -u ssh -n 50 | grep -i "failed"
```

---

### 6b. Proxmox Firewall & Network Status

```bash
# Check Proxmox VE Firewall status
pve-firewall status

# List active network interfaces
ip -c a
```

---

### 6c. SSL Certificate & ACME Renewal Check

```bash
# View SSL certificate expiration dates for Proxmox GUI
pvenode cert info

# Test ACME / Let's Encrypt renewal (if configured)
pvenode acme cert renew --force
```

---

## 7. Guest (VM & LXC) Maintenance Routine

### 7a. Guest OS Updating

Update packages inside active LXC containers:

```bash
# Execute package update inside LXC Container 102 (Pharmacy POS)
pct exec 102 -- apt update
pct exec 102 -- apt dist-upgrade -y
```

---

### 7b. QEMU Guest Agent & VirtIO Drivers Check

For QEMU Virtual Machines:

```bash
# Verify guest agent responsiveness
qm guest cmd <VMID> ping
```

---

### 7c. Stale Snapshot Cleanup

Inspect and remove old VM/LXC snapshots that consume storage delta space:

```bash
# List snapshots for LXC 102
pct listsnapshot 102

# Delete a stale snapshot
# pct delsnapshot 102 <snapshot_name>
```

---

## 8. Monthly Maintenance Checklist

Copy this checklist for operational record-keeping during monthly maintenance runs:

```markdown
### Proxmox VE Maintenance Run — Date: \***\*\_\_\_\_\*\*** Node: [ n150 / n100 ]

#### 1. System Updates & Kernel

- [ ] Pre-update storage and health check completed
- [ ] `apt-get dist-upgrade` completed without errors
- [ ] Kernel update status verified (`uname -r`)
- [ ] Graceful reboot completed (if kernel updated)
- [ ] Post-reboot services verified (`pvedaemon`, `pveproxy`)

#### 2. Storage & Hardware Health

- [ ] NVMe / SSD Wearout checked (`nvme smart-log` / `smartctl`)
- [ ] ZFS Scrub triggered and verified (`zpool scrub rpool`)
- [ ] LVM-Thin usage audited (< 85%)
- [ ] TRIM executed (`fstrim -av`)

#### 3. Log & Disk Maintenance

- [ ] Journald log size checked and vacuumed (`journalctl --vacuum-time=14d`)
- [ ] Temp files and old task logs cleaned

#### 4. Backup & Restore Drill

- [ ] VZDump backup logs verified on `n150`
- [ ] OneDrive sync verified (`systemctl status proxmox2onedrive.timer` + `journalctl -u proxmox2onedrive`)
- [ ] Backup transfer to `n100` confirmed
- [ ] Test restore drill executed successfully (Test VMID 999)

#### 5. Security & Guests

- [ ] SSH `authorized_keys` audited
- [ ] SSL certificate expiration checked
- [ ] Guest OS packages updated (`pct exec 102 -- apt dist-upgrade`)
- [ ] Stale snapshots removed
```
