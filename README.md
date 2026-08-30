# Home Repository

Infrastructure and operations knowledge base for a homelab and pharmacy deployment environment.

This repository is documentation-first and automation-assisted. It stores runbooks, maintenance procedures, backup scripts, systemd timer units, and security/certificate references used to operate production-like systems.

## What This Repo Contains

- Domain runbooks: Proxmox, OPNsense, BookStack, Pharmacy POS, Vault, Network, Smart Home
- Operational shell scripts: backups and synchronization workflows
- systemd unit files: scheduled automation wrappers for scripts
- Security references: Vault policy examples and TLS certificate procedures

## Tech Stack

- Markdown for runbooks and SOPs
- Bash for automation
- systemd (`.service` + `.timer`) for scheduling
- HCL for Vault policy
- OpenSSL workflows for certificate generation

Referenced infrastructure/services in docs:

- Proxmox VE, OPNsense HA firewall
- BookStack (Apache/PHP/MySQL)
- Pharmacy platform references (Rails API, React SPA, PostgreSQL, Redis, Sidekiq, Nginx)
- HashiCorp Vault
- rclone to OneDrive

## Architecture At A Glance

1. Operator starts from this README and picks a domain runbook.
2. Runbook provides step-by-step procedures and validation steps.
3. For recurring jobs, deploy script from `scripts/` to host (`/usr/local/bin/...`).
4. Enable paired systemd service/timer for scheduled execution.
5. Verify outcomes using host logs (`journalctl -u <service>`).

Data movement is centered around automated backup/sync:

- PostgreSQL dumps to local backup directory, then copied to OneDrive
- App storage directory synchronized to OneDrive
- Proxmox LXC dump files copied offsite to OneDrive
- Optional two-way dump replication between Proxmox nodes via `rclone bisync`

## Directory Guide

- `bookstack/`: BookStack install, backup/restore, HTTPS setup, installer script
- `github/`: Sysadmin-focused Git/GitHub usage notes
- `hashicorp-vault/`: Vault operational commands and access policy
- `images/`: Images embedded in docs
- `network/`: Current and failover network diagrams
- `opnsense/`: OPNsense install notes and HA maintenance runbooks (EN/VN)
- `pharmacy-pos/`: Deployment, migration, and backup instructions for pharmacy stack
- `proxmox/`: Proxmox maintenance and operational runbooks (EN/VN)
- `scripts/`: Executable backup/sync scripts and matching systemd unit files
- `smarthome/`: Smart-home operational notes
- `ssl_certificate/`: Self-signed certificate instructions and CA-related files

## Key Operational Files

- `scripts/backup-database.sh`
- `scripts/backup-photos.sh`
- `scripts/proxmox2onedrive_syc.sh`
- `scripts/proxmox-bisync.sh`
- `scripts/backup-database.service`
- `scripts/backup-database.timer`
- `scripts/backup-photos.service`
- `scripts/backup-photos.timer`
- `scripts/proxmox2onedrive.service`
- `scripts/proxmox2onedrive.timer`
- `scripts/proxmox-bisync.service`
- `scripts/proxmox-bisync.timer`

## Main Documentation Entry Points

- `bookstack/bookstack.md`
- `github/github-for-sysadmin.md`
- `network/network.md`
- `opnsense/opnsense.md`
- `opnsense/OPNSENSE_MAINTENANCE.md`
- `proxmox/proxmox.md`
- `pharmacy-pos/PHARMACY-POS.md`
- `hashicorp-vault/hashicorp-vault.md`
- `ssl_certificate/generate_self_signed_certification.md`

## Operating Principles

- Treat changes as infrastructure-impacting by default
- Keep script logic, timer schedule, and runbook documentation in sync
- Preserve defensive shell behavior (pre-flight checks, strict exits)
- Never commit secrets, private keys, or credentials
- Prefer explicit, reproducible, step-by-step procedures

## Quick Start

1. Read the relevant domain runbook.
2. Validate prerequisites and target host paths.
3. Apply/update script and matching systemd unit files.
4. Enable/start timer.
5. Verify success in logs and storage destination.
