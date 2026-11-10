# Hướng dẫn quét bảo mật VPS Ubuntu và website

Tài liệu này hướng dẫn dùng 3 script để kiểm tra **chính VPS và website của bạn** (`hoangquangtuong.site`): lỗ hổng cấu hình, file bị lộ, virus và dấu hiệu bị xâm nhập.

> **Chỉ quét máy và website do bạn sở hữu.** Quét hệ thống của người khác khi chưa được phép là vi phạm pháp luật.

Nội dung đầy đủ của 3 script nằm ở **Phụ lục** cuối tài liệu. Mỗi script lưu thành một file cùng tên trong thư mục `~` (thư mục home) của VPS.

---

## 1. Tổng quan

| Script | Làm gì | Chạy ở đâu | Thời gian |
|---|---|---|---|
| `scan.sh` | Kiểm tra tổng thể: cổng đang mở, tường lửa, nmap, nikto, header bảo mật, cập nhật Ubuntu, cấu hình SSH, `npm audit`, lynis | VPS | khoảng 5 đến 10 phút |
| `check-exposed.sh` | Dò xem web có để lộ file nhạy cảm không (`.env`, `.git`, backup, `package.json`...) | VPS hoặc máy Windows | dưới 1 phút |
| `scan-malware.sh` | Tìm virus, rootkit và dấu hiệu bị xâm nhập (tài khoản lạ, cron lạ, khóa SSH lạ, tiến trình lạ) | VPS | vài phút đến vài chục phút |

---

## 2. Chuẩn bị

### 2.1. Kết nối VPS

Dùng Bitvise (hoặc `ssh ubuntu@IP_VPS`), mở cửa sổ **New terminal console**.

### 2.2. Cài công cụ cho `scan.sh`

```bash
sudo apt update && sudo apt install -y nmap nikto lynis
```

`scan-malware.sh` tự cài công cụ của nó (ClamAV, rkhunter, chkrootkit). `check-exposed.sh` chỉ cần `curl` (có sẵn).

Nếu trong lúc cài hiện bảng **"Which services should be restarted?"**, gõ số của dòng `none of the above` rồi Enter để không restart dịch vụ nào lúc này.

### 2.3. Tạo file script bằng nano

Ví dụ với `scan.sh`:

```bash
cd ~
nano scan.sh
```

1. Chuột phải trong cửa sổ terminal để dán nội dung script (trong nano `Ctrl+V` **không** dán được).
2. Lưu: `Ctrl+O`, `Enter`.
3. Thoát: `Ctrl+X`.

Làm tương tự cho `check-exposed.sh` và `scan-malware.sh`. Không cần `chmod`, vì ta luôn chạy bằng `bash tên-file.sh`.

---

## 3. Lệnh chạy nhanh

```bash
# 1. Kiểm tra tổng thể (nên chạy nền)
nohup bash scan.sh > /dev/null 2>&1 &

# 2. Dò file bị lộ qua web
bash check-exposed.sh

# 3. Quét virus và dấu hiệu bị xâm nhập (chạy nền)
nohup bash scan-malware.sh > /dev/null 2>&1 &
```

**Vì sao chạy nền (`nohup ... &`)?** Phiên SSH có thể bị đứt giữa chừng (lần quét đầu của bạn đã bị văng). Chạy nền thì script vẫn tiếp tục, kết quả được lưu vào file báo cáo.

**Xem tiến độ:**

```bash
# báo cáo của scan.sh
tail -f $(ls -t ~/scan-report-*.txt | head -1)

# báo cáo của scan-malware.sh
tail -f $(ls -t ~/malware-report-*.txt | head -1)
```

`Ctrl+C` chỉ thoát phần xem, **không** dừng việc quét.

**Kiểm tra script còn chạy không:**

```bash
pgrep -af "scan.sh|scan-malware.sh"
```

---

## 4. `scan.sh`: kiểm tra tổng thể

Chạy `bash scan.sh` (hoặc chạy nền như trên). Báo cáo lưu ở `~/scan-report-<ngày-giờ>.txt`.

Nếu cần thêm thư mục web khác vào bước `npm audit`, sửa dòng `SITE_DIRS=(...)` ở đầu file.

### Cách đọc từng mục

| Mục | Bình thường | Cần chú ý |
|---|---|---|
| 1. Cổng đang mở | `80` (nginx), `22` (SSH). Ứng dụng Node (3000, 3001) chỉ nghe ở `127.0.0.1` | Thấy `0.0.0.0:3000` hoặc `0.0.0.0:3001`: ứng dụng nghe mọi địa chỉ (xem mục 8) |
| 2. Tường lửa | Chỉ mở cổng cần dùng | Thấy cổng lạ được mở |
| 3. nmap | Chỉ các cổng bạn chủ động dùng | Cổng database (3306, 5432, 6379, 27017...) mở ra ngoài |
| 4. nikto | Vài dòng về `/br/`, `/id/`, `/vi/` (trang ngôn ngữ, bình thường) | Xem phần "nikto báo hàng trăm mục" dưới đây |
| 5. Header bảo mật | `server: cloudflare` | Có `x-powered-by`, thiếu HSTS hoặc X-Frame-Options (mức nhẹ) |
| 6. Cập nhật bảo mật | "Không có gói bảo mật nào chờ cập nhật" | Có gói chờ: `sudo apt upgrade -y` rồi `sudo reboot` |
| 7. SSH | `passwordauthentication no`, `pubkeyauthentication yes` | `passwordauthentication yes` thì nên tắt; `permitrootlogin` nên là `no` |
| 8. npm audit | Không có lỗ hổng mức `high` hoặc `critical` | Xem phần "npm audit" dưới đây |
| 9. lynis | Cuối báo cáo có mục `Warnings` và `Suggestions` | Đọc các `Warnings` trước |

### nikto báo hàng trăm mục

Ứng dụng Next.js không có PHP, ASP hay CGI, nên các dòng nhắc tới phpMyAdmin, PHP-Nuke, file `.asp`, `.cgi`... **thường là báo nhầm**. Xác nhận bằng hai lệnh:

```bash
curl -s -o /dev/null -w '%{http_code}\n' 'http://127.0.0.1/snaptik/tmp_view.php?file=/etc/passwd'
curl -s 'http://127.0.0.1/snaptik/tmp_view.php?file=/etc/passwd' | grep -c 'root:x:0:0'
```

- Lệnh đầu ra `404`: ứng dụng không phục vụ file đó.
- Lệnh sau phải ra `0`: không có dòng thật nào của `/etc/passwd` bị lộ (dòng thật luôn bắt đầu bằng `root:x:0:0`). Lưu ý `grep 'root:'` ngắn có thể ra `1` vì chữ `root:` có trong chính trang 404 (CSS hoặc JS), nên đừng dùng mẫu ngắn đó.

### npm audit

- Xem riêng mục nghiêm trọng và cao:

```bash
cd ~/snaptik && npm audit --omit=dev 2>&1 | grep -B1 -A4 -iE 'Severity: (critical|high)' | head -80
```

- Nên xử lý trên **máy Windows**, không sửa trực tiếp trên VPS: chạy `npm audit fix`, chạy thử web, commit, push, rồi trên VPS `git pull`, `npm run build`, `pm2 restart snaptik`.
- **Không** chạy `npm audit fix --force`, vì có thể nâng Next.js lên bản chính mới và làm hỏng web.
- Mục `critical` của Next.js do phiên bản cũ. Nâng cấp lên bản chính mới là một việc riêng, cần lên kế hoạch và thử kỹ.

### lynis chạy riêng (nếu bước 9 bị ngắt)

```bash
nohup sudo lynis audit system --quick --no-colors > ~/lynis.txt 2>&1 &
# khoảng 2 phút sau:
tail -60 ~/lynis.txt
# xem riêng cảnh báo và gợi ý:
sudo grep -E '^(warning|suggestion)\[\]' /var/log/lynis-report.dat
```

---

## 5. `check-exposed.sh`: dò file bị lộ

```bash
bash check-exposed.sh                          # quét https://ten-mien.com và /example điền trong check-exposed.sh
bash check-exposed.sh https://ten-mien-khac.com   # quét địa chỉ khác của bạn
```

Script thử khoảng 40 đường dẫn nhạy cảm cho mỗi địa chỉ (mỗi lần cách nhau 0,2 giây). Nó chỉ báo khi một đường dẫn trả về `200` **và** khác với trang "không tồn tại" của chính web đó, nên không báo nhầm với web kiểu trang một trang (trả `200` cho mọi đường dẫn).

**Đọc kết quả:**

- `Không thấy file nhạy cảm nào trả về 200.` là tốt.
- Dòng `[CÓ THỂ BỊ LỘ] https://.../.env` nghĩa là đường dẫn đó đang trả về nội dung. Mở địa chỉ đó trên trình duyệt để xem có đúng là file thật không.

**Nếu thật sự bị lộ:**

1. Ngay lập tức coi mọi bí mật trong file đó (mật khẩu, khóa API, token) là đã lộ và **đổi chúng**.
2. Chuyển file ra khỏi thư mục web công khai (với Next.js, chỉ nội dung trong `public/` được phục vụ ra ngoài).
3. Chạy lại script để xác nhận đã hết.

---

## 6. `scan-malware.sh`: quét virus và dấu hiệu xâm nhập

```bash
nohup bash scan-malware.sh > /dev/null 2>&1 &
tail -f $(ls -t ~/malware-report-*.txt | head -1)
```

Nếu muốn thêm thư mục web chính vào mục "file web được sửa trong 3 ngày", sửa dòng `WEBDIRS=(...)` ở đầu file.

### Cách đọc từng mục

| Mục | Bình thường | Cần chú ý |
|---|---|---|
| Tài khoản có quyền root | Chỉ có `root` | Có tài khoản nào khác ở UID 0 |
| Tài khoản đăng nhập được | Chỉ `ubuntu` (và tài khoản bạn tạo) | Tài khoản lạ |
| Khóa SSH được phép | Chỉ khóa của bạn | Có khóa bạn không nhận ra |
| Cron | Trống hoặc các lệnh bạn biết | Lệnh tải file lạ hoặc chạy script lạ |
| 15 tiến trình tốn CPU | `node`, `nginx`, `pm2`... | Tiến trình lạ chiếm CPU liên tục (dấu hiệu đào coin) |
| Kết nối ra ngoài | Bạn (SSH), Cloudflare, TikTok | IP hoặc cổng lạ |
| Đăng nhập SSH thành công | Địa chỉ IP của bạn | IP lạ |
| File web sửa trong 3 ngày | Các file bạn vừa sửa | File bạn không nhớ đã sửa |
| File thực thi hoặc ẩn ở `/tmp` | Trống | File lạ |
| rkhunter, chkrootkit | Không cảnh báo | Xem lưu ý bên dưới |
| ClamAV | `Infected files: 0` | `Infected files` lớn hơn 0 |

### Lưu ý khi đọc kết quả

- **rkhunter hay báo nhầm trên Ubuntu** (ví dụ cảnh báo về cấu hình SSH hoặc file hệ thống quen thuộc). Đừng xóa file vội khi thấy `Warning`.
- **ClamAV chỉ nhận ra mã độc đã có chữ ký.** Không thấy gì chưa có nghĩa là chắc chắn sạch hoàn toàn.
- Nếu trang web có chức năng cho người dùng **tải file lên** (như Mini Drive): kiểm tra file tải lên được lưu ngoài thư mục web công khai, không bao giờ được chạy như mã (`.js`, `.sh`...), và có giới hạn loại file lẫn dung lượng. Đây là đường phổ biến nhất để gắn mã độc lên web.

---

## 7. Quét định kỳ bằng cron (tùy chọn)

```bash
crontab -e
```

Thêm các dòng sau (chạy lúc 3 giờ sáng thứ Hai hằng tuần và 4 giờ sáng Chủ nhật):

```
0 3 * * 1 bash $HOME/check-exposed.sh >> $HOME/check-exposed.log 2>&1
0 4 * * 0 bash $HOME/scan-malware.sh > /dev/null 2>&1
```

Các script dùng `sudo`, nên tài khoản `ubuntu` cần chạy `sudo` không hỏi mật khẩu (mặc định trên hầu hết VPS đám mây). Báo cáo `scan-malware.sh` vẫn được lưu ở `~/malware-report-*.txt`, nên nhớ thỉnh thoảng đọc lại, và xóa các báo cáo cũ để khỏi đầy ổ đĩa.

---

## 8. Việc nên làm sau khi quét (tùy kết quả)

| Việc | Cách làm |
|---|---|
| Ứng dụng Node chỉ nghe nội bộ | Trong `package.json` của snaptik: `"start": "next start -p 3001 -H 127.0.0.1"`, rồi `npm run build` và `pm2 restart snaptik`. Với web chính, đặt địa chỉ nghe là `127.0.0.1` trong code |
| Ẩn header `X-Powered-By: Next.js` | Trong `next.config.js` thêm `poweredByHeader: false` |
| Cấm root đăng nhập SSH | Đặt `PermitRootLogin no` trong `/etc/ssh/sshd_config`. **Trước khi restart** chạy `sudo sshd -t` kiểm tra cú pháp, giữ nguyên phiên SSH đang mở, mở thêm một phiên mới để thử đăng nhập trước khi đóng phiên cũ |
| Vá thư viện | `npm audit fix` trên máy Windows (không dùng `--force`), thử rồi mới đưa lên VPS |
| Áp dụng bản cập nhật hệ thống | Lúc ít người dùng: `sudo apt upgrade -y`, kiểm tra pm2 tự chạy lại sau khởi động (`systemctl is-enabled pm2-$USER`; nếu chưa thì `pm2 startup` rồi `pm2 save`), rồi `sudo reboot` |
| Mã hóa cả đoạn Cloudflare về VPS | Cài chứng chỉ (ví dụ certbot), mở cổng 443, đổi Cloudflare sang **Full (strict)** |

---

## 9. Nếu nghi ngờ VPS đã bị xâm nhập

1. **Đừng xóa file hay tắt dịch vụ vội.** Lưu lại báo cáo (`~/malware-report-*.txt`) làm bằng chứng.
2. Đổi khóa SSH: tạo khóa mới, xóa khóa lạ khỏi `~/.ssh/authorized_keys`.
3. Đổi mọi bí mật có trên VPS (mật khẩu, token, khóa API trong file `.env` và cơ sở dữ liệu).
4. Xem lại log đăng nhập: `sudo grep 'Accepted' /var/log/auth.log | tail -50` và `last -a | head -30`.
5. Nếu xác nhận bị xâm nhập thật, cách an toàn nhất là **dựng lại VPS từ bản sạch**, rồi đưa code lên lại từ git thay vì sao chép file cũ.

---

## 10. Xử lý sự cố thường gặp

| Hiện tượng | Nguyên nhân và cách xử lý |
|---|---|
| Đang quét thì SSH bị văng | Mạng hoặc phiên SSH bị đứt (không phải do hết RAM). Chạy nền bằng `nohup ... &` như mục 3 |
| `sudo: nano: command not found` hoặc không dán được | Dán bằng chuột phải, không dùng `Ctrl+V` |
| `freshclam` báo file khóa (locked) | Script đã tạm dừng dịch vụ `clamav-freshclam` trước khi cập nhật. Nếu chạy tay thì `sudo systemctl stop clamav-freshclam` trước |
| `nikto: command not found` | Chưa cài: `sudo apt install -y nikto` |
| `npm audit` báo `ENOTFOUND` hoặc không chạy | Kiểm tra VPS có mạng: `curl -sI https://registry.npmjs.org \| head -1` |
| Báo cáo không thấy file | Xem `ls -t ~/scan-report-*.txt ~/malware-report-*.txt` |

---

# Phụ lục: nội dung các script

Lưu mỗi đoạn dưới đây thành file cùng tên trong thư mục `~` của VPS.

