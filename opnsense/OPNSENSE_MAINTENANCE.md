# OPNsense High Availability Firewall Maintenance Runbook

A comprehensive operational runbook for maintaining, updating, and auditing the OPNsense High Availability (HA) firewall pair running in CARP, XMLRPC sync, and Kea DHCP HA Peers mode.

---

## Table of Contents

1. [System Overview & HA Architecture](#1-system-overview--ha-architecture)
2. [Zero-Downtime Monthly Update & Patching Procedure](#2-zero-downtime-monthly-update--patching-procedure)
   - [2a. Pre-Update Preparation & Backups](#2a-pre-update-preparation--backups)
   - [2b. Step 1: Update Secondary Firewall (`firewall-s`)](#2b-step-1-update-secondary-firewall-firewall-s)
   - [2c. Step 2: Controlled CARP Failover Test](#2c-step-2-controlled-carp-failover-test)
   - [2d. Step 3: Update Primary Firewall (`firewall-p`)](#2d-step-3-update-primary-firewall-firewall-p)
   - [2e. Step 4: Failback & Post-Update Verification](#2e-step-4-failback--post-update-verification)
3. [High Availability & Synchronization Audit](#3-high-availability--synchronization-audit)
   - [3a. CARP Virtual IP Status Audit](#3a-carp-virtual-ip-status-audit)
   - [3b. pfsync State Table Replication Check](#3b-pfsync-state-table-replication-check)
   - [3c. XMLRPC Configuration Sync Test](#3c-xmlrpc-configuration-sync-test)
   - [3d. Kea DHCP HA Peers & Lease Sync Audit](#3d-kea-dhcp-ha-peers--lease-sync-audit)
4. [System Performance & Capacity Health Checks](#4-system-performance--capacity-health-checks)
   - [4a. Firewall State Table Utilization](#4a-firewall-state-table-utilization)
   - [4b. Gateway & Upstream ISP Latency (dpinger)](#4b-gateway--upstream-isp-latency-dpinger)
   - [4c. Disk Space & Log Partition Audit](#4c-disk-space--log-partition-audit)
5. [Log Management & Storage Maintenance](#5-log-management--storage-maintenance)
   - [5a. Circular Log Vacuuming & Rotation](#5a-circular-log-vacuuming--rotation)
   - [5b. Configuration Revision History Pruning](#5b-configuration-revision-history-pruning)
6. [Automated Backup & Disaster Recovery](#6-automated-backup--disaster-recovery)
   - [6a. Manual & API XML Configuration Backup](#6a-manual--api-xml-configuration-backup)
   - [6b. Proxmox VM Snapshot Hygiene](#6b-proxmox-vm-snapshot-hygiene)
7. [Security Services & VPN Audit](#7-security-services--vpn-audit)
   - [7a. Rule Base & NAT Audit](#7a-rule-base--nat-audit)
   - [7b. SSL/TLS Certificate Expiration Check](#7b-ssltls-certificate-expiration-check)
   - [7c. IPS / Suricata / Zenarmor Signatures Update](#7c-ips--suricata--zenarmor-signatures-update)
8. [Monthly HA Firewall Maintenance Checklist](#8-monthly-ha-firewall-maintenance-checklist)

---

## 1. System Overview & HA Architecture

| Firewall Role | Node Name | Host Proxmox Node | HA State (Default) | Primary Responsibilities |
| ------------- | --------- | ----------------- | ------------------ | ------------------------ |
| **Primary**   | `firewall-p` | `n100` (Proxmox)  | CARP Master        | Handles all incoming/outgoing traffic, routes, NAT, VPNs, Kea DHCP Primary HA Peer. Source of XMLRPC config sync. |
| **Secondary** | `firewall-s` | `n150` (Proxmox)  | CARP Backup        | Standby firewall with mirrored pfsync states, Kea DHCP Secondary HA Peer. Receives XMLRPC config from `firewall-p`. Takes over instantly if `n100` or `firewall-p` fails. |

### High Availability Components
- **CARP (Common Address Redundancy Protocol):** Provides shared Virtual IPs (VIPs) on WAN/LAN interfaces.
- **pfsync:** Replicates connection state tables in real time over a dedicated HA sync link between `n100` and `n150`.
- **XMLRPC Sync:** Pushes firewall rules, aliases, Kea DHCP subnet configurations, static reservations, and settings from `firewall-p` (Master) to `firewall-s` (Backup).
- **Kea DHCP HA Peers:** Real-time DHCPv4/v6 lease database synchronization between `firewall-p` (Primary HA Peer) and `firewall-s` (Secondary HA Peer) via Kea Control Agent HTTP/HTTPS API (port 8000).

---

## 2. Zero-Downtime Monthly Update & Patching Procedure

> ⚠️ **CRITICAL RULE FOR HA UPGRADES:** Always update the **Secondary (`firewall-s`) FIRST**, test failover, and then update the **Primary (`firewall-p`) SECOND**. Never update the Primary master node first.

> ℹ️ **Kea DHCP HA Behavior During Updates:** When `firewall-s` is updated or rebooted, Kea DHCP on `firewall-p` automatically transitions to single-peer mode (`partner-down`) and continues serving DHCP leases without interruption. When `firewall-s` boots up, Kea HA automatically re-synchronizes the lease database (`syncing` → `ready`).

---

### 2a. Pre-Update Preparation & Backups

Execute these steps before starting any upgrade:

1. **Verify Current HA & Kea Sync Status:**  
   - On `firewall-p`, navigate to **System → High Availability → Status**. Confirm all CARP interfaces are **MASTER** on `firewall-p` and no sync errors are reported.
   - On `firewall-p`, navigate to **Services → Kea DHCP → Status / Log Files** and verify Kea HA Peers relationship is active (`ready`).

2. **Download OPNsense XML Configuration Backup:**  
   On `firewall-p`, go to **System → Configuration → Backups** and click **Download Configuration**. Save the file locally (`config-firewall-p-YYYYMMDD.xml`).

3. **Take Proxmox Hypervisor Snapshots:**  
   Before upgrading software, take a VM snapshot on both Proxmox hosts:
   ```bash
   # On Proxmox n100 (Primary host):
   qm snapshot <FIREWALL_P_VMID> pre-update-YYYYMMDD

   # On Proxmox n150 (Secondary host):
   qm snapshot <FIREWALL_S_VMID> pre-update-YYYYMMDD
   ```

---

### 2b. Step 1: Update Secondary Firewall (`firewall-s`)

1. Log into the Web GUI of **`firewall-s`** (Secondary, running on Proxmox `n150`).
2. Navigate to **System → Firmware → Updates**.
3. Click **Check for updates**.
4. Click **Update** (or **Upgrade** for major releases).
5. Allow `firewall-s` to download packages, apply updates, and reboot automatically.
6. Once rebooted, log back into `firewall-s` and verify system health:
   ```bash
   # Via SSH / Console option 13 or shell:
   opnsense-version
   ```
7. Confirm in **System → High Availability → Status** that `firewall-s` interfaces are in **BACKUP** state.
8. Verify Kea DHCP service automatically reconnected to `firewall-p` and completed lease sync.

---

### 2c. Step 2: Controlled CARP Failover Test

Test failover to verify that `firewall-s` successfully routes network traffic under the new firmware.

1. **Initiate Controlled Failover from `firewall-p`:**  
   On `firewall-p`, navigate to **System → High Availability → Status**.  
   Click **Enable Persistent CARP Maintenance** (or run `configctl interface carp demote` via SSH).

2. **Verify CARP State Shift:**
   - On `firewall-p`: VIP status changes from `MASTER` → `DISABLED/MAINTENANCE`.
   - On `firewall-s`: VIP status changes from `BACKUP` → `MASTER`.

3. **Verify Network Connectivity & DHCP Responses During Failover:**  
   Run a continuous ping test from a client workstation (`ping 1.1.1.1`) and test renewing a DHCP lease (`ipconfig /renew` or `dhclient -r && dhclient`).  
   *Expected Result:* 0 to 1 dropped packets during transition; Kea DHCP on `firewall-s` responds to DHCP requests immediately.

4. **Verify Application & Stateful Session Persistence:**  
   Confirm active TCP connections (SSH, web browsing, POS terminal backend calls) remain alive thanks to `pfsync`.

---

### 2d. Step 3: Update Primary Firewall (`firewall-p`)

With traffic safely running through `firewall-s`:

1. Log into the Web GUI of **`firewall-p`** (Primary, running on Proxmox `n100`).
2. Navigate to **System → Firmware → Updates**.
3. Click **Check for updates** and then **Update**.
4. Allow `firewall-p` to complete the installation and reboot.
5. After reboot, log in via SSH or Web GUI and verify system status.

---

### 2e. Step 4: Failback & Post-Update Verification

1. **Disable CARP Maintenance Mode on `firewall-p`:**  
   On `firewall-p`, go to **System → High Availability → Status** and click **Disable Persistent CARP Maintenance**.

2. **Confirm Master Failback:**
   - `firewall-p` VIPs transition back to **MASTER**.
   - `firewall-s` VIPs transition back to **BACKUP**.

3. **Verify XMLRPC & Kea HA Sync:**  
   On `firewall-p`, go to **Firewall → Aliases**, edit a description of an alias, and click **Save & Apply**. Confirm modification synced to `firewall-s`.  
   Check Kea DHCP HA status (**Services → Kea DHCP → Log Files**) to confirm Kea HA Peers state is `ready`.

---

## 3. High Availability & Synchronization Audit

Perform these checks monthly to ensure failover readiness.

### 3a. CARP Virtual IP Status Audit

```bash
# SSH into firewall-p (Master):
configctl interface carp status

# Expected output on firewall-p:
# master

# SSH into firewall-s (Backup):
configctl interface carp status

# Expected output on firewall-s:
# backup
```

---

### 3b. pfsync State Table Replication Check

Compare active state counts between both firewalls to ensure pfsync is mirroring connections:

```bash
# Check state count on firewall-p:
pfctl -si | grep "current entries"

# Check state count on firewall-s:
pfctl -si | grep "current entries"
```

*The entry count on `firewall-s` should closely match `firewall-p` (typically within 5-10% threshold).*

---

### 3c. XMLRPC Configuration Sync Test

1. On `firewall-p`, navigate to **System → High Availability → Settings**.
2. Verify all required synchronization items are checked (**Firewall Rules**, **Aliases**, **NAT**, **Kea DHCP Server / Control Agent**, **Virtual IPs**, **Unbound DNS**).
3. Inspect `firewall-p` sync log at **System → Log Files → General** for any `xmlrpc` error messages.

---

### 3d. Kea DHCP HA Peers & Lease Sync Audit

Since Kea DHCP uses dedicated HA Peers for real-time lease replication:

1. **Kea Service Status Check:**  
   On both nodes, navigate to **Services → Kea DHCP → Kea DHCPv4** (and Control Agent). Confirm services are running.

2. **Kea HA Peers Relationship Check:**  
   Navigate to **Services → Kea DHCP → Log Files / Status**.  
   Verify the HA state:
   - Primary (`firewall-p`): `ready` (or `hot-standby`)
   - Secondary (`firewall-s`): `ready` (or `hot-standby`)

3. **Kea Lease Database Synchronization Verification:**  
   Check active DHCP leases on both firewalls under **Services → Kea DHCP → Leases**.  
   Verify that client lease IP/MAC mappings issued by `firewall-p` are mirrored in `firewall-s`'s lease table.

4. **Kea Control Agent Port Verification:**  
   Ensure HTTP/HTTPS communications over Kea Control Agent port (`8000` or configured HA port) between `firewall-p` and `firewall-s` are allowed by local firewall rules on the HA sync interface.

---

## 4. System Performance & Capacity Health Checks

### 4a. Firewall State Table Utilization

Check state table size against maximum limits:

```bash
# Inspect state table memory usage
pfctl -sm

# View current active state summary
pfctl -s info | grep -E "current entries|searches|inserts"
```

> 💡 **Threshold Warning:** If current entries exceed 70% of maximum state limit, increase memory allocation or adjust state timeouts in **Firewall → Settings → Advanced**.

---

### 4b. Gateway & Upstream ISP Latency (dpinger)

Check latency and packet loss to upstream gateways:

1. Navigate to **Reporting → Gateway**.
2. Inspect `dpinger` metrics for WAN interfaces.
3. *Action Threshold:* Packet loss > 2% or latency spikes > 100ms require ISP ticket investigation.

---

### 4c. Disk Space & Log Partition Audit

```bash
# Check disk usage via SSH shell (Option 8):
df -h / /var /tmp

# Check top log consumers in /var/log/
du -sh /var/log/* | sort -rh | head -n 10
```

> ⚠️ **Warning:** If `/var` disk usage exceeds 85%, clean old log files or adjust circular log sizes.

---

## 5. Log Management & Storage Maintenance

### 5a. Circular Log Vacuuming & Rotation

OPNsense uses circular log files (`clog`) or standard syslog.

1. Navigate to **System → Settings → Logging**.
2. Verify log size limits (default 512KB to 10MB per log file).
3. Flush old logs if storage is constrained:
   ```bash
   # Reset log files via CLI (if needed)
   clog -i -s 262144 /var/log/filter/filter_latest.log
   ```

---

### 5b. Configuration Revision History Pruning

Excessive configuration history revisions slow down XMLRPC sync.

1. Navigate to **System → Configuration → History**.
2. Click **Cleanup** to purge revisions older than 30 days or keep the latest 50 revisions.

---

## 6. Automated Backup & Disaster Recovery

### 6a. Manual & API XML Configuration Backup

Export the XML config file after major rule modifications:

- **Web GUI:** **System → Configuration → Backups → Download Configuration**.
- **Automated API Backup Script:**
  ```bash
  curl -k -u "KEY:SECRET" https://firewall-p/api/core/backup/download/this -o opnsense-backup-$(date +%Y%m%m).xml
  ```

---

### 6b. Proxmox VM Snapshot Hygiene

After completing monthly updates and confirming 48 hours of stable operation, **delete temporary pre-update hypervisor snapshots** to save storage IOPS and disk space:

```bash
# Delete snapshot on Proxmox n100:
qm delsnapshot <FIREWALL_P_VMID> pre-update-YYYYMMDD

# Delete snapshot on Proxmox n150:
qm delsnapshot <FIREWALL_S_VMID> pre-update-YYYYMMDD
```

---

## 7. Security Services & VPN Audit

### 7a. Rule Base & NAT Audit

1. Review WAN firewall rules (**Firewall → Rules → WAN**). Ensure no unnecessary open ports or permissive `any → any` rules exist.
2. Review Port Forwarding (**Firewall → NAT → Port Forward**) and outbound NAT rules.

---

### 7b. SSL/TLS Certificate Expiration Check

1. Navigate to **System → Trust → Certificates**.
2. Inspect expiration dates for Web GUI SSL certificates, OpenVPN CA, and client certificates.
3. *Action:* Renew any certificates expiring within 30 days.

---

### 7c. IPS / Suricata / Zenarmor Signatures Update

If running Intrusion Detection (Suricata) or Sensei/Zenarmor:

1. Navigate to **Services → Intrusion Detection → Administration**.
2. Click **Download Rules** to update IPS signatures.
3. Verify signature update timestamp is current.

---

## 8. Monthly HA Firewall Maintenance Checklist

Copy this checklist for operational record-keeping during monthly maintenance runs:

```markdown
### OPNsense HA Maintenance Run — Date: ____________ Node: [ firewall-p / firewall-s ]

#### 1. Pre-Update & Backups
- [ ] Verified CARP status: `firewall-p` is MASTER, `firewall-s` is BACKUP
- [ ] Kea DHCP HA Peers status verified (`ready` state on both nodes)
- [ ] XML configuration downloaded & archived from `firewall-p`
- [ ] Proxmox hypervisor snapshots created (`n100` and `n150`)

#### 2. Firmware Updates & Failover
- [ ] Secondary `firewall-s` updated & rebooted FIRST
- [ ] Persistent CARP maintenance mode enabled on `firewall-p`
- [ ] CARP failover to `firewall-s` verified (ping test 0 packet loss)
- [ ] Kea DHCP lease renewal tested during failover
- [ ] Primary `firewall-p` updated & rebooted SECOND
- [ ] CARP maintenance mode disabled; `firewall-p` failback to MASTER confirmed
- [ ] XMLRPC sync test performed and verified
- [ ] Kea DHCP HA Peers re-synchronization confirmed (`ready` state)

#### 3. System Health & Capacity
- [ ] State table utilization checked (`pfctl -si`)
- [ ] Gateway dpinger latency/loss checked
- [ ] Disk space checked (`df -h`, `/var` < 85%)
- [ ] Configuration history revision logs pruned

#### 4. Security & Cleanup
- [ ] Certificate expiration dates checked (> 30 days remaining)
- [ ] IPS / Suricata rules updated
- [ ] Temporary Proxmox pre-update snapshots deleted after stability check
```
