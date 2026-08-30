# Hướng Dẫn Bảo Trì & Vận Hành Proxmox VE (Runbook)

Tài liệu quy trình chuẩn để bảo trì, cập nhật và tối ưu hóa hệ thống máy chủ Proxmox Virtual Environment (PVE) cho các node `n150` và `n100`.

---

## Mục Lục

1. [Danh Sách Máy Chủ & Tổng Quan Hệ Thống](#1-danh-sách-máy-chủ--tổng-quan-hệ-thống)
2. [Quy Trình Cập Nhật & Vá Lỗi Proxmox VE Hàng Tháng](#2-quy-trình-cập-nhật--vá-lỗi-proxmox-ve-hàng-tháng)
   - [2a. Kiểm Tra Sức Khỏe Trước Khi Update](#2a-kiểm-tra-sức-khỏe-trước-khi-update)
   - [2b. Cấu Hình Kho Repository (No-Subscription)](#2b-cấu-hình-kho-repository-no-subscription)
   - [2c. Thực Hiện Cập Nhật Hệ Thống](#2c-thực-hiện-cập-nhật-hệ-thống)
   - [2d. Cập Nhật Kernel & Quy Trình Khởi Động Lại An Toàn](#2d-cập-nhật-kernel--quy-trình-khởi-động-lại-an-toàn)
3. [Giám Sát Bộ Nhớ & Phần Cứng Storage](#3-giám-sát-bộ-nhớ--phần-cứng-storage)
   - [3a. Kiểm Tra Độ Mòn NVMe & SSD SMART](#3a-kiểm-tra-độ-mòn-nvme--ssd-smart)
   - [3b. Kiểm Tra Sức Khỏe & Scrubbing ZFS Pool Hàng Tháng](#3b-kiểm-tra-sức-khỏe--scrubbing-zfs-pool-hàng-tháng)
   - [3c. Kiểm Tra LVM-Thin Pool & Dung Lượng Lưu Trữ](#3c-kiểm-tra-lvm-thin-pool--dung-lượng-lưu-trữ)
   - [3d. Thực Thi Lệnh TRIM Ổ Cứng](#3d-thực-thi-lệnh-trim-ổ-cứng)
4. [Dọn Dẹp Log Hệ Thống & Bộ Nhớ Đệm](#4-dọn-dẹp-log-hệ-thống--bộ-nhớ-đệm)
   - [4a. Thu Gom & Giới Hạn Nhật Ký Journald](#4a-thu-gom--giới-hạn-nhật-ký-journald)
   - [4b. Dọn Dẹp File Tạm & Core Dumps](#4b-dọn-dẹp-file-tạm--core-dumps)
5. [Kiểm Tra Tiến Trình Backup & Diễn Tập Phục Hồi](#5-kiểm-tra-tiến-trình-backup--diễn-tập-phục-hồi)
   - [5a. Kiểm Tra Lịch Backup VZDump Trên Node `n150`](#5a-kiểm-tra-lịch-backup-vzdump-trên-node-n150)
   - [5b. Kiểm Tra Chuyển Bản Backup Sang Node `n100`](#5b-kiểm-tra-chuyển-bản-backup-sang-node-n100)
   - [5c. Diễn Tập Phục Hồi Thử Hàng Tháng](#5c-diễn-tập-phục-hồi-thử-hàng-tháng)
6. [Kiểm Tra Bảo Mật & Quyền Truy Cập](#6-kiểm-tra-bảo-mật--quyền-truy-cập)
   - [6a. Kiểm Tra Bảo Mật SSH & Xác Thực](#6a-kiểm-tra-bảo-mật-ssh--xác-thực)
   - [6b. Trạng Thái Firewall Proxmox & Mạng](#6b-trạng-thái-firewall-proxmox--mạng)
   - [6c. Kiểm Tra Hạn Chứng Chỉ SSL & Gia Hạn ACME](#6c-kiểm-tra-hạn-chứng-chỉ-ssl--gia-hạn-acme)
7. [Bảo Trì Hệ Thống Khách (VM & LXC Container)](#7-bảo-trì-hệ-thống-khách-vm--lxc-container)
   - [7a. Cập Nhật Hệ Điều Hành Trong LXC/VM](#7a-cập-nhật-hệ-điều-hành-trong-lxcvm)
   - [7b. Kiểm Tra QEMU Guest Agent & Driver VirtIO](#7b-kiểm-tra-qemu-guest-agent--driver-virtio)
   - [7c. Dọn Dẹp Bản Chụp Snapshot Cũ](#7c-dọn-dẹp-bản-chụp-snapshot-cũ)
8. [Danh Sách Kiểm Tra Bảo Trì Hàng Tháng (Checklist)](#8-danh-sách-kiểm-tra-bảo-trì-hàng-tháng-checklist)

---

## 1. Danh Sách Máy Chủ & Tổng Quan Hệ Thống

> **Phiên Bản Proxmox VE:** 9
> **Thông Tin Đăng Nhập:** lưu trong Bitwarden

| Tên Node   | Hostname | Vi Xử Lý   | Địa Chỉ IP      | Giao Diện Web                                            | Vai Trò            | Nhiệm Vụ Chính / Workload                                                                                            |
| ---------- | -------- | ---------- | --------------- | -------------------------------------------------------- | ------------------ | -------------------------------------------------------------------------------------------------------------------- |
| **`n100`** | `pve`    | Intel N100 | `192.168.31.10` | [n100.ducloi6.dpdns.org](https://n100.ducloi6.dpdns.org) | Node Proxmox Chính | OPNsense chính. Pharmacy POS & Backend (đang di chuyển sang node này).<br>Lịch Backup tự động hàng ngày lúc `22:45`. |
| **`n150`** | `n150`   | Intel N150 | `192.168.31.30` | [n150.ducloi6.dpdns.org](https://n150.ducloi6.dpdns.org) | Node Proxmox Phụ   | Máy chủ dự phòng Disaster Recovery & Nơi lưu trữ backup phụ.                                                         |

---

## 2. Quy Trình Cập Nhật & Vá Lỗi Proxmox VE Hàng Tháng

Thực hiện quy trình này **mỗi tháng một lần** (khuyên dùng trong khung giờ bảo trì). Thực hiện lần lượt trên từng node (ví dụ: cập nhật `n100` trước, kiểm tra ổn định rồi mới cập nhật `n150`).

### 2a. Kiểm Tra Sức Khỏe Trước Khi Update

Chạy trên node cần update:

```bash
# 1. Kiểm tra trạng thái cluster (nếu có cụm cluster)
pvecm status

# 2. Kiểm tra dung lượng ổ đĩa hệ thống (đảm bảo / và /var không đầy)
df -h / /var /var/lib/vz

# 3. Kiểm tra các tiến trình đang chạy trong Proxmox
pvesh get /nodes/localhost/tasks

# 4. Kiểm tra kết nối mạng Internet
ping -c 3 1.1.1.1
```

---

### 2b. Cấu Hình Kho Repository (No-Subscription)

Nếu sử dụng phiên bản không đăng ký Enterprise, hãy xác nhận kho package no-subscription đã được bật đúng cách.

#### Tắt Enterprise Repository (nếu không có bản quyền)

Sửa file `/etc/apt/sources.list.d/pve-enterprise.list`:

```apt
# deb https://enterprise.proxmox.com/debian/pve bookworm pve-enterprise
```

#### Bật No-Subscription Repository

Sửa file `/etc/apt/sources.list.d/pve-no-subscription.list` (hoặc `/etc/apt/sources.list`):

```apt
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
```

---

### 2c. Thực Hiện Cập Nhật Hệ Thống

Chạy các lệnh cập nhật từ giao diện CLI của Proxmox Host:

```bash
# 1. Cập nhật danh sách gói package
apt update

# 2. Xem danh sách các gói có thể nâng cấp
apt list --upgradable

# 3. Nâng cấp hệ thống (KHÔNG dùng lệnh 'apt upgrade')
apt-get dist-upgrade -y

# Hoặc dùng lệnh wrapper chính thức của Proxmox:
# pveupgrade
```

> ⚠️ **QUAN TRỌNG:** Luôn dùng `apt-get dist-upgrade` hoặc `pveupgrade`. Không dùng `apt upgrade` vì có thể gây thiếu package phụ thuộc hoặc hỏng kernel Proxmox.

---

### 2d. Cập Nhật Kernel & Quy Trình Khởi Động Lại An Toàn

#### Kiểm Tra Xem Có Kernel Mới Cần Reboot Không

So sánh phiên bản kernel đang chạy và bản mới nhất vừa cài:

```bash
# Phiên bản kernel đang chạy:
uname -r

# Danh sách kernel Proxmox đã cài:
dpkg -l | grep -E "proxmox-kernel|pve-kernel" | grep "^ii" | tail -n 3
```

Nếu có kernel mới được cài đặt, hãy sắp xếp lịch reboot máy chủ.

#### Quy Trình Tắt Workload & Reboot Máy Chủ

##### Bước 1: Tắt Hoặc Dịch Chuyển Các VM/LXC Trạng Thái Chạy

Đối với **`n100`** (Node phụ):

```bash
# Tắt an toàn các container/VM thử nghiệm:
pct list
pct stop <VMID>
```

Đối với **`n150`** (Node chính):

```bash
# Tắt an toàn LXC container sản xuất:
pct stop 102    # Tắt LXC Pharmacy POS Application
```

##### Bước 2: Khởi Động Lại Host Node

```bash
systemctl reboot
```

##### Bước 3: Kiểm Tra Sau Khi Khởi Động Lại

```bash
# 1. Kiểm tra kernel mới đang hoạt động
uname -r

# 2. Kiểm tra trạng thái các service Proxmox
systemctl status pvedaemon pveproxy pvestatd

# 3. Bật lại LXC container / VM
pct start 102

# 4. Truy cập thử giao diện Proxmox Web GUI
curl -k https://localhost:8006
```

---

## 3. Giám Sát Bộ Nhớ & Phần Cứng Storage

### 3a. Kiểm Tra Độ Mòn NVMe & SSD SMART

Kiểm tra sức khỏe và chỉ số độ mòn (wearout) của ổ đĩa hàng tháng để chủ động thay thế đĩa trước khi hỏng.

```bash
# Cài đặt công cụ kiểm tra smartmontools & nvme-cli
apt install -y smartmontools nvme-cli

# Liệt kê thiết bị lưu trữ
lsblk

# Kiểm tra sức khỏe & chỉ số Wearout ổ NVMe
nvme smart-log /dev/nvme0n1

# Kiểm tra trạng thái SMART ổ SATA SSD / HDD
smartctl -H /dev/sda
smartctl -A /dev/sda | grep -i wear
```

#### Ngưỡng Cảnh Báo Sức Khỏe Ổ Cứng

| Chỉ Số                       | Ý Nghĩa            | Ngưỡng Cần Thao Tác                 |
| ---------------------------- | ------------------ | ----------------------------------- |
| NVMe `percentage_used`       | Tỷ lệ độ mòn %     | > 80% → Lập kế hoạch thay ổ mới     |
| SATA SSD `Wearout_Indicator` | Mức độ mòn còn lại | < 20% còn lại → Lập kế hoạch thay ổ |
| SMART `overall-health`       | Kết quả test SMART | `FAILED` → Thay ổ ngay lập tức      |

---

### 3b. Kiểm Tra Sức Khỏe & Scrubbing ZFS Pool Hàng Tháng

Nếu hệ thống sử dụng ZFS Pool (`rpool`):

```bash
# 1. Kiểm tra trạng thái pool và lỗi đĩa
zpool status -x

# 2. Chạy kiểm tra tính toàn vẹn dữ liệu (Scrubbing)
zpool scrub rpool

# 3. Theo dõi tiến trình scrub
zpool status rpool
```

---

### 3c. Kiểm Tra LVM-Thin Pool & Dung Lượng Lưu Trữ

Nếu hệ thống sử dụng LVM-Thin:

```bash
# Kiểm tra dung lượng volume group và thin pool
pvs
vgs
lvs -a
```

> ⚠️ **Cảnh báo:** Tuyệt đối không để LVM-Thin pool đầy 100%. Nếu mức sử dụng vượt 85%, hãy mở rộng dung lượng hoặc xóa bớt file đĩa không dùng.

---

### 3d. Thực Thi Lệnh TRIM Ổ Cứng

Chạy `fstrim` để dải ô đĩa SSD/NVMe giải phóng các khối dữ liệu không còn sử dụng:

```bash
# Trim tất cả các filesystem hỗ trợ
fstrim -av
```

Đảm bảo systemd trim timer đang hoạt động:

```bash
systemctl enable --now fstrim.timer
systemctl status fstrim.timer
```

---

## 4. Dọn Dẹp Log Hệ Thống & Bộ Nhớ Đệm

### 4a. Thu Gom & Giới Hạn Nhật Ký Journald

Tránh để `/var/log/journal` phình to chiếm hết dung lượng phân vùng root.

```bash
# Kiểm tra dung lượng log hiện tại
du -sh /var/log/journal

# Thu gom xóa bớt log cũ hơn 14 ngày
journalctl --vacuum-time=14d

# Giới hạn tổng dung lượng log journal tối đa 1 GB
journalctl --vacuum-size=1G
```

---

## 5. Kiểm Tra Tiến Trình Backup & Diễn Tập Phục Hồi

### 5a. Kiểm Tra Lịch Backup VZDump Trên Node `n150`

Xác nhận tiến trình backup tự động lúc `22:45` trên `n150` hoạt động bình thường:

```bash
# Xem danh sách log VZDump
ls -lt /var/log/vzdump/ | head -n 5
tail -n 20 /var/log/vzdump/vzdump-lxc-102-*.log
```

---

### 5b. Kiểm Tra Chuyển Bản Backup Sang Node `n100`

Đảm bảo file backup được đồng bộ sang `n100`:

```bash
# Kiểm tra file backup mới nhất trên n100
ssh root@n100 "ls -lh /var/lib/vz/dump/"
```

---

### 5c. Diễn Tập Phục Hồi Thử Hàng Tháng

Thực hiện restore thử nghiệm LXC Container (`102`) sang node `n100` với ID thử nghiệm (ví dụ `999`):

```bash
# 1. Restore container với ID thử nghiệm 999 trên n100
pct restore 999 /var/lib/vz/dump/vzdump-lxc-102-*.tar.zst --storage local-lvm

# 2. Khởi động container thử nghiệm
pct start 999

# 3. Test ứng dụng bên trong container thử nghiệm
pct exec 999 -- curl -I http://localhost/health

# 4. Dọn dẹp xóa container thử nghiệm sau khi hoàn tất diễn tập
pct stop 999
pct destroy 999
```

---

## 6. Kiểm Tra Bảo Mật & Quyền Truy Cập

### 6a. Kiểm Tra Bảo Mật SSH & Xác Thực

```bash
# 1. Kiểm tra cấu hình đăng nhập root qua SSH
grep -i "PermitRootLogin" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*

# 2. Kiểm tra danh sách SSH public key được phép đăng nhập
cat /root/.ssh/authorized_keys

# 3. Xem nhật ký thử đăng nhập thất bại
journalctl -u ssh -n 50 | grep -i "failed"
```

---

### 6b. Trạng Thái Firewall Proxmox & Mạng

```bash
# Kiểm tra trạng thái Firewall Proxmox
pve-firewall status

# Hiển thị danh sách card mạng đang hoạt động
ip -c a
```

---

## 7. Bảo Trì Hệ Thống Khách (VM & LXC Container)

### 7a. Cập Nhật Hệ Điều Hành Trong LXC/VM

Cập nhật các gói package bên trong LXC container 102 (Pharmacy POS):

```bash
# Chạy cập nhật bên trong LXC 102 từ máy chủ Proxmox Host
pct exec 102 -- apt update
pct exec 102 -- apt dist-upgrade -y
```

---

### 7b. Dọn Dẹp Bản Chụp Snapshot Cũ

Xóa bớt các bản snapshot cũ không còn sử dụng để tránh tốn dung lượng đĩa:

```bash
# Xem danh sách snapshot của LXC 102
pct listsnapshot 102

# Xóa snapshot cũ
# pct delsnapshot 102 <tên_snapshot>
```

---

## 8. Danh Sách Kiểm Tra Bảo Trì Hàng Tháng (Checklist)

Sao chép phiếu này để ghi chép trong mỗi đợt bảo trì hệ thống hàng tháng:

```markdown
### Nhật Ký Bảo Trì Proxmox VE — Ngày: \***\*\_\_\_\_\*\*** Node: [ n150 / n100 ]

#### 1. Cập Nhật Hệ Thống & Kernel

- [ ] Kiểm tra dung lượng đĩa trước khi update
- [ ] Chạy `apt-get dist-upgrade` thành công không lỗi
- [ ] Kiểm tra phiên bản kernel mới (`uname -r`)
- [ ] Khởi động lại server an toàn (nếu có nâng cấp kernel)
- [ ] Kiểm tra lại các service Proxmox sau khi khởi động (`pvedaemon`, `pveproxy`)

#### 2. Bộ Nhớ & Sức Khỏe Phần Cứng

- [ ] Kiểm tra độ mòn NVMe / SSD Wearout (`nvme smart-log` / `smartctl`)
- [ ] Chạy ZFS Scrubbing (`zpool scrub rpool`)
- [ ] Kiểm tra dung lượng LVM-Thin pool (< 85%)
- [ ] Chạy lệnh TRIM ổ cứng (`fstrim -av`)

#### 3. Log System & Dọn Dẹp

- [ ] Dọn dẹp bớt log nhật ký journald (`journalctl --vacuum-time=14d`)
- [ ] Xóa file tạm và log tiến trình cũ

#### 4. Backup & Diễn Tập Restore

- [ ] Kiểm tra log VZDump backup trên `n150`
- [ ] Khai báo & xác nhận file backup đã truyền sang `n100`
- [ ] Thực hiện restore thử nghiệm thành công (Test VMID 999)

#### 5. Bảo Mật & Virtual Machine

- [ ] Rà soát danh sách SSH key trong `authorized_keys`
- [ ] Kiểm tra hạn chứng chỉ SSL giao diện Proxmox
- [ ] Cập nhật OS bên trong LXC container (`pct exec 102 -- apt dist-upgrade`)
- [ ] Xóa bỏ các bản snapshot không dùng
```
