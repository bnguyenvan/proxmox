# Hướng Dẫn Bảo Trì Firewall OPNsense High Availability (Runbook)

Tài liệu quy trình chuẩn để bảo trì, cập nhật firmware và kiểm tra an toàn cho cặp Firewall OPNsense High Availability (HA) chạy chế độ đồng bộ CARP, XMLRPC sync và Kea DHCP HA Peers.

---

## Mục Lục

1. [Tổng Quan Hệ Thống & Kiến Trúc HA](#1-tổng-quan-hệ-thống--kiến-trúc-ha)
2. [Quy Trình Cập Nhật Firmware Không Gây Gián Đoạn Mạng (Zero-Downtime)](#2-quy-trình-cập-nhật-firmware-không-gây-gián-đoạn-mạng-zero-downtime)
   - [2a. Chuẩn Bị & Sao Lưu Trước Khi Update](#2a-chuẩn-bị--sao-lưu-trước-khi-update)
   - [2b. Bước 1: Cập Nhật Firewall Phụ (`firewall-s`)](#2b-bước-1-cập-nhật-firewall-phụ-firewall-s)
   - [2c. Bước 2: Thử Nghiệm Chuyển Mạch CARP Failover Bằng Lệnh](#2c-bước-2-thử-nghiệm-chuyển-mạch-carp-failover-bằng-lệnh)
   - [2d. Bước 3: Cập Nhật Firewall Chính (`firewall-p`)](#2d-bước-3-cập-nhật-firewall-chính-firewall-p)
   - [2e. Bước 4: Chuyển Về Trạng Thái Ban Đầu & Kiểm Tra](#2e-bước-4-chuyển-về-trạng-thái-ban-đầu--kiểm-tra)
3. [Kiểm Tra Trạng Thái High Availability & Đồng Bộ](#3-kiểm-tra-trạng-thái-high-availability--đồng-bộ)
   - [3a. Kiểm Tra Trạng Thái CARP Virtual IP](#3a-kiểm-tra-trạng-thái-carp-virtual-ip)
   - [3b. Kiểm Tra Đồng Bộ Bảng Trạng Thái pfsync](#3b-kiểm-tra-đồng-bộ-bảng-trạng-thái-pfsync)
   - [3c. Kiểm Tra Đồng Bộ Cấu Hình XMLRPC](#3c-kiểm-tra-đồng-bộ-cấu-hình-xmlrpc)
   - [3d. Kiểm Tra Cụm Kea DHCP HA Peers & Đồng Bộ Lease IP](#3d-kiểm-tra-cụm-kea-dhcp-ha-peers--đồng-bộ-lease-ip)
4. [Kiểm Tra Sức Khỏe Hiệu Năng & Dung Lượng](#4-kiểm-tra-sức-khỏe-hiệu-năng--dung-lượng)
   - [4a. Kiểm Tra Mức Sử Dụng Bảng Trạng Thái State Table](#4a-kiểm-tra-mức-sử-dụng-bảng-trạng-thái-state-table)
   - [4b. Kiểm Tra Trạng Thái Gateway & Độ Trễ ISP (dpinger)](#4b-kiểm-tra-trạng-thái-gateway--độ-trễ-isp-dpinger)
   - [4c. Kiểm Tra Dung Lượng Ổ Đĩa & Phân Vùng Log](#4c-kiểm-tra-dung-lượng-ổ-đĩa--phân-vùng-log)
5. [Quản Lý Log & Dọn Dẹp Bộ Nhớ Lưu Trữ](#5-quản-lý-log--dọn-dẹp-bộ-nhớ-lưu-trữ)
   - [5a. Xoay Log & Dọn Dẹp Log Nhật Ký](#5a-xoay-log--dọn-dẹp-log-nhật-ký)
   - [5b. Dọn Dẹp Lịch Sử Cấu Hình (Configuration History)](#5b-dọn-dẹp-lịch-sử-cấu-hình-configuration-history)
6. [Sao Lưu Cấu Hình Tự Động & Phục Hồi Thảm Họa](#6-sao-lưu-cấu-hình-tự-động--phục-hồi-thảm-họa)
   - [6a. Sao Lưu File XML Cấu Hình](#6a-sao-lưu-file-xml-cấu-hình)
   - [6b. Dọn Dẹp Snapshot VM Trên Proxmox](#6b-dọn-dẹp-snapshot-vm-trên-proxmox)
7. [Bảo Trì Các Dịch Vụ Bảo Mật & VPN](#7-bảo-trì-các-dịch-vụ-bảo-mật--vpn)
   - [7a. Rà Soát Quy Tắc Firewall & Lệnh NAT](#7a-rà-soát-quy-tắc-firewall--lệnh-nat)
   - [7b. Kiểm Tra Hạn Chứng Chỉ SSL/TLS](#7b-kiểm-tra-hạn-chứng-chỉ-ssltls)
   - [7c. Cập Nhật Mẫu Nhận Dạng Lỗ Hổng IPS / Suricata / Zenarmor](#7c-cập-nhật-mẫu-nhận-dạng-lỗ-hổng-ips--suricata--zenarmor)
8. [Danh Sách Kiểm Tra Bảo Trì HA Firewall Hàng Tháng (Checklist)](#8-danh-sách-kiểm-tra-bảo-trì-ha-firewall-hàng-tháng-checklist)

---

## 1. Tổng Quan Hệ Thống & Kiến Trúc HA

| Vai Trò Firewall | Tên Node   | Node Proxmox Chứa VM | Trạng Thái HA (Mặc Định) | Nhiệm Vụ Chính |
| ---------------- | ---------- | -------------------- | ------------------------ | -------------- |
| **Primary**      | `firewall-p` | `n100` (Proxmox)     | CARP Master              | Xử lý toàn bộ lưu lượng mạng ra/vào, routing, NAT, VPN, Kea DHCP Primary HA Peer. Là gốc đẩy cấu hình XMLRPC. |
| **Secondary**    | `firewall-s` | `n150` (Proxmox)     | CARP Backup              | Máy chủ dự phòng chạy song song, đồng bộ bảng trạng thái kết nối qua pfsync, Kea DHCP Secondary HA Peer. Tự động tiếp quản tức thì nếu `n100` hoặc `firewall-p` gặp sự cố. |

### Các Thành Phần Kiến Trúc HA
- **CARP (Common Address Redundancy Protocol):** Tạo các IP ảo chung (Virtual IP - VIP) trên các card WAN/LAN.
- **pfsync:** Đồng bộ bảng trạng thái kết nối TCP/UDP theo thời gian thực qua đường cáp sync riêng giữa `n100` và `n150`.
- **XMLRPC Sync:** Tự động đẩy các rule firewall, alias, cấu hình subnet Kea DHCP, gán IP tĩnh và cài đặt từ `firewall-p` (Master) sang `firewall-s` (Backup).
- **Kea DHCP HA Peers:** Đồng bộ CSDL cấp phát IP (lease database) theo thời gian thực giữa `firewall-p` (Primary HA Peer) và `firewall-s` (Secondary HA Peer) qua API Kea Control Agent (port 8000).

---

## 2. Quy Trình Cập Nhật Firmware Không Gây Gián Đoạn Mạng (Zero-Downtime)

> ⚠️ **QUY TẮC BẮT BUỘC KHI UPDATE CỤM HA:** Luôn cập nhật **Firewall Phụ (`firewall-s`) TRƯỚC**, thử nghiệm failover, sau đó mới cập nhật **Firewall Chính (`firewall-p`) SAU**. Tuyệt đối không update máy chủ Master trước.

> ℹ️ **Cơ Chế Kea DHCP HA Khi Update:** Khi `firewall-s` đang khởi động lại hoặc nâng cấp, Kea DHCP trên `firewall-p` tự động chuyển sang chế độ đơn nút (`partner-down`) và tiếp tục cấp phát IP DHCP bình thường không bị gián đoạn. Khi `firewall-s` lên lại, Kea HA sẽ tự động đồng bộ lại CSDL lease (`syncing` → `ready`).

---

### 2a. Chuẩn Bị & Sao Lưu Trước Khi Update

Thực hiện các bước sau trước khi bấm nâng cấp:

1. **Xác Nhận Trạng Thái Đồng Bộ HA & Kea Peers:**  
   - Trên `firewall-p`, mở **System → High Availability → Status**. Xác nhận các Virtual IP đang ở trạng thái **MASTER** và không có lỗi sync.
   - Mở **Services → Kea DHCP → Status / Log Files**, xác nhận cụm Kea HA Peers đang ở trạng thái hoạt động (`ready`).

2. **Tải Bản Sao Lưu Cấu Hình XML:**  
   Vào `firewall-p`, mở **System → Configuration → Backups**, nhấn **Download Configuration** để lưu file cấu hình phòng ngừa (`config-firewall-p-YYYYMMDD.xml`).

3. **Tạo Snapshot Máy Ảo Trên Proxmox Host:**  
   Tạo snapshot nhanh cho các VM firewall trước khi update:
   ```bash
   # Trên Proxmox n100 (Primary Host):
   qm snapshot <VMID_FIREWALL_P> pre-update-YYYYMMDD

   # Trên Proxmox n150 (Secondary Host):
   qm snapshot <VMID_FIREWALL_S> pre-update-YYYYMMDD
   ```

---

### 2b. Bước 1: Cập Nhật Firewall Phụ (`firewall-s`)

1. Đăng nhập vào giao diện Web GUI của **`firewall-s`** (Secondary, chạy trên Proxmox `n150`).
2. Truy cập **System → Firmware → Updates**.
3. Nhấn **Check for updates**.
4. Nhấn **Update** (hoặc **Upgrade** nếu nâng cấp phiên bản lớn).
5. Để `firewall-s` tự động tải gói, cài đặt và khởi động lại.
6. Sau khi `firewall-s` khởi động xong, đăng nhập lại và kiểm tra phiên bản:
   ```bash
   # Kiểm tra qua SSH / Console shell:
   opnsense-version
   ```
7. Kiểm tra mục **System → High Availability → Status**, đảm bảo các VIP trên `firewall-s` vẫn ở trạng thái **BACKUP**.
8. Kiểm tra dịch vụ Kea DHCP đã tự động kết nối lại với `firewall-p` và hoàn tất đồng bộ lease IP.

---

### 2c. Bước 2: Thử Nghiệm Chuyển Mạch CARP Failover Bằng Lệnh

Chuyển mạng sang `firewall-s` để kiểm tra firmware mới chạy có ổn định không:

1. **Bật Chế Độ Bảo Trì CARP Trên `firewall-p`:**  
   Vào Web GUI của `firewall-p`, mở **System → High Availability → Status**.  
   Nhấn **Enable Persistent CARP Maintenance** (hoặc chạy lệnh `configctl interface carp demote` qua SSH).

2. **Xác Nhận Chuyển Trạng Thái CARP:**
   - Trên `firewall-p`: Trạng thái VIP chuyển sang `DISABLED/MAINTENANCE`.
   - Trên `firewall-s`: Trạng thái VIP chuyển sang `MASTER`.

3. **Kiểm Tra Kết Nối Mạng & Cấp Phát DHCP Khi Chuyển Mạch:**  
   Mở terminal máy tính khách chạy lệnh ping liên tục ra Internet (`ping 1.1.1.1`) và xin cấp lại IP (`ipconfig /renew` hoặc `dhclient -r && dhclient`).  
   *Kết quả kỳ vọng:* Mất từ 0 đến tối đa 1 gói ping; Kea DHCP trên `firewall-s` phản hồi và cấp phát IP bình thường.

4. **Kiểm Tra Các Phiên Kết Nối Đang Chạy:**  
   Kiểm tra các kết nối SSH, truy cập web, phần mềm POS vẫn duy trì thông suốt nhờ tính năng đồng bộ `pfsync`.

---

### 2d. Bước 3: Cập Nhật Firewall Chính (`firewall-p`)

Sau khi xác nhận mạng chạy ổn định qua `firewall-s`:

1. Đăng nhập Web GUI của **`firewall-p`** (Primary, chạy trên Proxmox `n100`).
2. Mở **System → Firmware → Updates**.
3. Nhấn **Check for updates** và nhấn **Update**.
4. Chờ `firewall-p` cài đặt xong và tự động khởi động lại.
5. Sau khi khởi động xong, đăng nhập kiểm tra trạng thái hệ thống.

---

### 2e. Bước 4: Chuyển Về Trạng Thái Ban Đầu & Kiểm Tra

1. **Tắt Chế Độ Bảo Trì CARP Trên `firewall-p`:**  
   Vào `firewall-p`, mở **System → High Availability → Status**, nhấn **Disable Persistent CARP Maintenance**.

2. **Xác Nhận Trạng Thái Trả Về Ban Đầu:**
   - VIP trên `firewall-p` quay lại trạng thái **MASTER**.
   - VIP trên `firewall-s` quay lại trạng thái **BACKUP**.

3. **Kiểm Tra Đồng Bộ XMLRPC & Kea HA Peers:**  
   Trên `firewall-p`, vào **Firewall → Aliases**, sửa thử một mô tả của alias bất kỳ và nhấn **Save & Apply**. Kiểm tra `firewall-s` đã cập nhật theo chưa.  
   Mở **Services → Kea DHCP → Log Files** kiểm tra cụm Kea HA Peers đã báo trạng thái `ready`.

---

## 3. Kiểm Tra Trạng Thái High Availability & Đồng Bộ

### 3a. Kiểm Tra Trạng Thái CARP Virtual IP

```bash
# SSH vào firewall-p (Master):
configctl interface carp status
# Kết quả kỳ vọng: master

# SSH vào firewall-s (Backup):
configctl interface carp status
# Kết quả kỳ vọng: backup
```

---

### 3b. Kiểm Tra Đồng Bộ Bảng Trạng Thái pfsync

So sánh số lượng kết nối đang được theo dõi giữa 2 firewall:

```bash
# Xem số lượng state trên firewall-p:
pfctl -si | grep "current entries"

# Xem số lượng state trên firewall-s:
pfctl -si | grep "current entries"
```

*Số lượng bản ghi trên `firewall-s` phải xấp xỉ tương đương `firewall-p` (độ lệch thường dưới 5-10%).*

---

### 3c. Kiểm Tra Đồng Bộ Cấu Hình XMLRPC

1. Trên `firewall-p`, mở **System → High Availability → Settings**.
2. Đảm bảo các mục cần sync được tích chọn (**Firewall Rules**, **Aliases**, **NAT**, **Kea DHCP Server / Control Agent**, **Virtual IPs**, **Unbound DNS**).
3. Kiểm tra log sync trên `firewall-p` tại **System → Log Files → General** xem có báo lỗi `xmlrpc` nào không.

---

### 3d. Kiểm Tra Cụm Kea DHCP HA Peers & Đồng Bộ Lease IP

Kea DHCP sử dụng giao thức HA Peers riêng để nhân bản dữ liệu lease IP theo thời gian thực:

1. **Kiểm Tra Trạng Thái Dịch Vụ Kea:**  
   Trên cả 2 node, mở **Services → Kea DHCP → Kea DHCPv4** và **Control Agent**. Xác nhận các service đều đang hoạt động (`running`).

2. **Kiểm Tra Trạng Thái Kết Nối Kea HA Peers:**  
   Vào **Services → Kea DHCP → Log Files / Status**.  
   Xác nhận trạng thái HA:
   - Primary (`firewall-p`): `ready` (hoặc `hot-standby`)
   - Secondary (`firewall-s`): `ready` (hoặc `hot-standby`)

3. **Kiểm Tra Đồng Bộ Bảng Cấp Phát Lease IP:**  
   Kiểm tra bảng lease DHCP trên cả 2 firewall tại **Services → Kea DHCP → Leases**.  
   Xác nhận các IP/MAC được `firewall-p` cấp phát đều xuất hiện song song trên bảng lease của `firewall-s`.

4. **Kiểm Tra Port Kết Nối Kea Control Agent:**  
   Đảm bảo cổng HTTP/HTTPS của Kea Control Agent (mặc định port `8000` hoặc port cấu hình HA) giữa `firewall-p` và `firewall-s` được phép thông suốt qua rule firewall trên interface đồng bộ HA.

---

## 4. Kiểm Tra Sức Khỏe Hiệu Năng & Dung Lượng

### 4a. Kiểm Tra Mức Sử Dụng Bảng Trạng Thái State Table

```bash
# Xem giới hạn bảng trạng thái
pfctl -sm

# Xem số lượng kết nối active hiện tại
pfctl -s info | grep -E "current entries|searches|inserts"
```

> 💡 **Cảnh báo ngưỡng:** Nếu số lượng connection vượt quá 70% giới hạn tối đa, hãy tăng dung lượng RAM cho VM hoặc điều chỉnh timeout trong **Firewall → Settings → Advanced**.

---

### 4b. Kiểm Tra Trạng Thái Gateway & Độ Trễ ISP (dpinger)

1. Mở **Reporting → Gateway**.
2. Kiểm tra biểu đồ độ trễ và tỷ lệ mất gói của các đường WAN.
3. *Ngưỡng xử lý:* Mất gói > 2% hoặc latency vọt > 100ms cần kiểm tra lại đường truyền với nhà mạng ISP.

---

### 4c. Kiểm Tra Dung Lượng Ổ Đĩa & Phân Vùng Log

```bash
# Kiểm tra dung lượng đĩa qua SSH shell:
df -h / /var /tmp

# Kiểm tra thư mục log chiếm dung lượng lớn trong /var/log/
du -sh /var/log/* | sort -rh | head -n 10
```

> ⚠️ **Cảnh báo:** Nếu phân vùng `/var` đầy quá 85%, hãy dọn bớt file log cũ.

---

## 5. Quản Lý Log & Dọn Dẹp Bộ Nhớ Lưu Trữ

### 5a. Xoay Log & Dọn Dẹp Log Nhật Ký

1. Vào **System → Settings → Logging**.
2. Xác nhận dung lượng tối đa của các file log (mặc định 512KB đến 10MB mỗi file).
3. Reset các file log cũ nếu bộ nhớ bị hạn chế:
   ```bash
   clog -i -s 262144 /var/log/filter/filter_latest.log
   ```

---

### 5b. Dọn Dẹp Lịch Sử Cấu Hình (Configuration History)

Quá nhiều bản ghi lịch sử cấu hình cũ sẽ làm chậm tiến trình đồng bộ XMLRPC.

1. Vào **System → Configuration → History**.
2. Nhấn **Cleanup** để xóa bớt các bản ghi cũ hơn 30 ngày hoặc chỉ giữ lại 50 phiên bản gần nhất.

---

## 6. Sao Lưu Cấu Hình Tự Động & Phục Hồi Thảm Họa

### 6a. Sao Lưu File XML Cấu Hình

Tải bản sao lưu file cấu hình XML sau các đợt chỉnh sửa rule lớn:

- **Web GUI:** **System → Configuration → Backups → Download Configuration**.
- **Tự động tải qua API:**
  ```bash
  curl -k -u "API_KEY:API_SECRET" https://firewall-p/api/core/backup/download/this -o opnsense-backup-$(date +%Y%m%m).xml
  ```

---

### 6b. Dọn Dẹp Snapshot VM Trên Proxmox

Sau khi hoàn tất cập nhật firmware và hệ thống chạy ổn định sau 48 giờ, hãy **xóa các bản snapshot tạm trên Proxmox host** để giải phóng tài nguyên đĩa:

```bash
# Xóa snapshot trên Proxmox n100:
qm delsnapshot <VMID_FIREWALL_P> pre-update-YYYYMMDD

# Xóa snapshot trên Proxmox n150:
qm delsnapshot <VMID_FIREWALL_S> pre-update-YYYYMMDD
```

---

## 7. Bảo Trì Các Dịch Vụ Bảo Mật & VPN

### 7a. Rà Soát Quy Tắc Firewall & Lệnh NAT

1. Rà soát các rule mạng WAN (**Firewall → Rules → WAN**). Đảm bảo không có các port mở thừa hoặc rule cho phép quá rộng (`any → any`).
2. Rà soát danh sách Port Forward (**Firewall → NAT → Port Forward**).

---

### 7b. Kiểm Tra Hạn Chứng Chỉ SSL/TLS

1. Mở **System → Trust → Certificates**.
2. Kiểm tra ngày hết hạn của chứng chỉ Web GUI, OpenVPN CA và các certificate khách.
3. *Thao tác:* Gia hạn các chứng chỉ có thời hạn còn lại dưới 30 ngày.

---

### 7c. Cập Nhật Mẫu Nhận Dạng Lỗ Hổng IPS / Suricata / Zenarmor

1. Mở **Services → Intrusion Detection → Administration**.
2. Nhấn **Download Rules** để cập nhật các mẫu nhận dạng mã độc mới nhất.
3. Kiểm tra mốc thời gian cập nhật rule.

---

## 8. Danh Sách Kiểm Tra Bảo Trì HA Firewall Hàng Tháng (Checklist)

Sao chép phiếu này để ghi chép trong mỗi đợt bảo trì hệ thống hàng tháng:

```markdown
### Nhật Ký Bảo Trì OPNsense HA Firewall — Ngày: ____________ Node: [ firewall-p / firewall-s ]

#### 1. Chuẩn Bị & Sao Lưu
- [ ] Kiểm tra CARP: `firewall-p` là MASTER, `firewall-s` là BACKUP
- [ ] Kiểm tra cụm Kea DHCP HA Peers (trạng thái `ready` trên cả 2 node)
- [ ] Tải file cấu hình XML backup từ `firewall-p`
- [ ] Tạo snapshot VM trên Proxmox host (`n100` và `n150`)

#### 2. Cập Nhật Firmware & Failover
- [ ] Cập nhật & reboot Firewall Phụ `firewall-s` TRƯỚC
- [ ] Bật chế độ CARP Maintenance trên `firewall-p`
- [ ] Xác nhận CARP Failover sang `firewall-s` thành công (ping không rớt gói)
- [ ] Kiểm tra tính năng cấp phát IP của Kea DHCP khi failover
- [ ] Cập nhật & reboot Firewall Chính `firewall-p` SAU
- [ ] Tắt CARP Maintenance; xác nhận `firewall-p` quay lại MASTER
- [ ] Kiểm tra tính năng đồng bộ XMLRPC hoạt động tốt
- [ ] Kiểm tra cụm Kea DHCP HA Peers đồng bộ lại trạng thái `ready`

#### 3. Sức Khỏe & Hiệu Năng Hệ Thống
- [ ] Kiểm tra bảng trạng thái kết nối (`pfctl -si`)
- [ ] Kiểm tra độ trễ gateway dpinger
- [ ] Kiểm tra dung lượng đĩa (`df -h`, `/var` < 85%)
- [ ] Dọn dẹp bớt lịch sử phiên bản cấu hình

#### 4. Bảo Mật & Dọn Dẹp
- [ ] Kiểm tra thời hạn chứng chỉ SSL (> 30 ngày)
- [ ] Cập nhật mẫu rule IPS / Suricata
- [ ] Xóa bỏ snapshot tạm trên Proxmox host sau 48h ổn định
```
