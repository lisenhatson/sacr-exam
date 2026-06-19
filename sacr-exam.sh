#!/bin/bash

# === PENGATURAN GOOGLE SHEET ===
GSHEET_WEB_APP_URL="-"

# === PENGATURAN TELEGRAM ===
BOT_TOKEN=""
CHAT_ID=""

# === INPUT PESERTA ===
read -p "Masukkan nama peserta: " PESERTA

# === KONFIGURASI ===
SCORE=0
M1="machine1.sacr.id"
M2="machine2.sacr.id"
USER="sysadmin"
PASS="sysadmin"
REPORT="/tmp/sacr_report_${PESERTA// /_}.txt"
TIME_LOG="/tmp/sacr_start_time.log"
touch $REPORT

# Deteksi Disk
ROOT_DISK=$(df / | awk 'NR==2 {print $1}' | sed 's/[0-9]*$//' | xargs basename 2>/dev/null)

if [ -z "$ROOT_DISK" ]; then
    # Fallback: coba dari lsblk
    ROOT_DISK=$(lsblk -n -o NAME,MOUNTPOINT 2>/dev/null | grep -w '/' | awk '{print $1}' | sed 's/[0-9]*$//')
fi

if [ -z "$ROOT_DISK" ]; then
    log "ERROR: Tidak dapat menentukan root disk."
    exit 1
fi

TEST_DISK=$(lsblk -nd -o NAME,TYPE,SIZE | grep -v "$ROOT_DISK" | grep disk | awk '{print $1}' | head -n1)

if [ -z "$TEST_DISK" ]; then
    # Fallback
    if [ -b /dev/vdb ]; then
        TEST_DISK="vdb"
    elif [ -b /dev/sdb ]; then
        TEST_DISK="sdb"
    else
        log "ERROR: Tidak dapat menemukan disk tambahan. Pastikan sudah menambahkan virtual disk."
        exit 1
    fi
fi

DISK="/dev/$TEST_DISK"
log "Disk yang terdeteksi: $DISK"
###


# === HITUNG DURASI PENGERJAAN ===
if [ -f "$TIME_LOG" ]; then
    START_TIME=$(cat "$TIME_LOG")
    END_TIME=$(date +%s)
    TOTAL_SECONDS=$((END_TIME - START_TIME))
    MINUTES=$((TOTAL_SECONDS / 60))
    SECONDS=$((TOTAL_SECONDS % 60))
    DURASI_PENGERJAAN="${MINUTES} menit ${SECONDS} detik"
    rm "$TIME_LOG"
else
    DURASI_PENGERJAAN="Tidak tercatat"
fi

# === FUNGSI ===
check_remote() {
    sshpass -p "$PASS" ssh -q -o StrictHostKeyChecking=no -o ConnectTimeout=5 $USER@$1 "$2" 2>/dev/null
}
log() {
    echo -e "$1" | tee -a "$REPORT"
}

log ""
log "=== SYSADMIN REPORT ==="
log "Peserta: $PESERTA"
log "Tanggal: $(date)"
log "Waktu Pengerjaan: $WAKTU_PENGERJAAN"
log ""

# ==========================================================
# LOGIKA PENILAIAN
# ==========================================================
log "==================== BASIC CONFIGURATION ===================="
if check_remote $M1 "hostnamectl 2>/dev/null | grep -q 'machine1.sacr.id'" && check_remote $M2 "hostnamectl 2>/dev/null | grep -q 'machine2.sacr.id'"; then SCORE=$((SCORE+3)); log "✔ Hostname sesuai"; else log "✘ Hostname salah"; fi
if check_remote $M1 "grep -q '^PermitRootLogin no' /etc/ssh/sshd_config 2>/dev/null" && check_remote $M2 "grep -q '^PermitRootLogin no' /etc/ssh/sshd_config 2>/dev/null"; then SCORE=$((SCORE+3)); log "✔ SSH non-root login OK"; else log "✘ SSH belum diset non-root"; fi

log "==================== LINUX FUNDAMENTAL ===================="
if check_remote $M1 "[ -d ~/ujian_sacr ] && [ -f ~/ujian_sacr/audit.sh ]"; then SCORE=$((SCORE+2)); log "✔ Folder ujian_sacr dan audit.sh ada"; else log "✘ Folder ujian_sacr atau audit.sh tidak ada"; fi
if check_remote $M1 "[ \"\$(stat -c '%a' ~/ujian_sacr/audit.sh 2>/dev/null)\" = '750' ]"; then SCORE=$((SCORE+2)); log "✔ Permission audit.sh benar"; else log "✘ Permission audit.sh salah"; fi
if check_remote $M1 "getent group cyber &>/dev/null"; then SCORE=$((SCORE+2)); log "✔ Group cyber ada"; else log "✘ Group cyber belum ada"; fi
if check_remote $M1 "id analyst &>/dev/null && id analyst | grep -q cyber"; then SCORE=$((SCORE+2)); log "✔ User analyst sesuai"; else log "✘ User analyst belum sesuai"; fi
if check_remote $M1 "[ -d ~/projek_linux ]"; then SCORE=$((SCORE+2)); log "✔ Direktori projek_linux ada"; else log "✘ Direktori projek_linux belum ada"; fi
if check_remote $M1 "[ -f ~/projek_linux/readme.txt ] && [ -f ~/projek_linux/config.txt ]"; then SCORE=$((SCORE+2)); log "✔ File projek_linux lengkap"; else log "✘ File projek_linux belum lengkap"; fi
if check_remote $M1 "[ -f ~/projek_linux/readme_backup.txt ]"; then SCORE=$((SCORE+2)); log "✔ Backup file berhasil dibuat"; else log "✘ Backup file belum dibuat"; fi
if check_remote $M1 "[ -f ~/arsip/laporan_final.txt ]"; then SCORE=$((SCORE+2)); log "✔ laporan_final.txt ditemukan"; else log "✘ laporan_final.txt tidak ditemukan"; fi
if check_remote $M1 "getent group tim_it &>/dev/null"; then SCORE=$((SCORE+2)); log "✔ Group tim_it ada"; else log "✘ Group tim_it belum ada"; fi
if check_remote $M1 "id operator01 &>/dev/null && id operator01 | grep -q tim_it"; then SCORE=$((SCORE+2)); log "✔ User operator01 sesuai"; else log "✘ User operator01 belum sesuai"; fi

log "==================== SERVER FUNDAMENTAL ===================="
if check_remote $M1 "[ -f ~/.ssh/ujian_key ] && [ -f ~/.ssh/ujian_key.pub ]"; then SCORE=$((SCORE+4)); log "✔ SSH key ujian_key ada"; else log "✘ SSH key belum dibuat"; fi
if check_remote $M1 "systemctl is-active ssh 2>/dev/null | grep -q active"; then SCORE=$((SCORE+2)); log "✔ Service SSH aktif"; else log "✘ Service SSH tidak aktif"; fi
if check_remote $M1 "systemctl is-active mariadb 2>/dev/null | grep -q active"; then SCORE=$((SCORE+4)); log "✔ MariaDB aktif"; else log "✘ MariaDB tidak aktif"; fi
if check_remote $M1 "sudo mariadb -e \"SELECT User FROM mysql.user\" 2>/dev/null | grep -q user_ujian"; then SCORE=$((SCORE+4)); log "✔ User MariaDB user_ujian ada"; else log "✘ User MariaDB belum dibuat"; fi
if check_remote $M1 "systemctl is-active nginx 2>/dev/null | grep -q active"; then SCORE=$((SCORE+4)); log "✔ Nginx aktif"; else log "✘ Nginx tidak aktif"; fi
if check_remote $M1 "sudo nginx -T 2>/dev/null | grep -q 'listen 8080'"; then SCORE=$((SCORE+4)); log "✔ Nginx listen 8080"; else log "✘ Konfigurasi Nginx salah"; fi
if check_remote $M1 "curl -s localhost:8080 >/dev/null 2>&1"; then SCORE=$((SCORE+3)); log "✔ Website dapat diakses"; else log "✘ Website tidak dapat diakses"; fi
if check_remote $M1 "sudo ufw status 2>/dev/null | grep -q '22/tcp'"; then SCORE=$((SCORE+2)); log "✔ Rule SSH ada"; else log "✘ Rule SSH tidak ditemukan"; fi
if check_remote $M1 "sudo ufw status 2>/dev/null | grep -q '8080'"; then SCORE=$((SCORE+2)); log "✔ Rule port 8080 ada"; else log "✘ Rule port 8080 tidak ditemukan"; fi
if check_remote $M1 "sudo ufw status 2>/dev/null | grep -q '3306'"; then SCORE=$((SCORE+2)); log "✔ Rule port 3306 ada"; else log "✘ Rule port 3306 tidak ditemukan"; fi

log "==================== DOCKER WEB ===================="
if check_remote $M2 "docker image ls 2>/dev/null | grep -q 'sacr-web-image'"; then SCORE=$((SCORE+4)); log "✔ Image ada"; else log "✘ Image belum dibuat"; fi
if check_remote $M2 "docker ps --filter name=sacr-web-con --format '{{.Ports}}' 2>/dev/null | grep -q '8080->'"; then SCORE=$((SCORE+4)); log "✔ Container jalan dan port 8080 terbuka"; else log "✘ Container belum / port belum sesuai"; fi
if check_remote $M2 "curl -s localhost:8080 >/dev/null 2>&1"; then SCORE=$((SCORE+3)); log "✔ Website bisa dibuka"; else log "✘ Website gagal"; fi

#
log "==================== PARTISI & FILESYSTEM ===================="
if check_remote "lsblk ${DISK}1 2>/dev/null"; then
    SCORE=$((SCORE+2)); log "✔ Partisi ${DISK}1 ditemukan"
else
    log "✘ Partisi ${DISK}1 tidak ada"
fi

if check_remote "lsblk ${DISK}2 2>/dev/null"; then
    SCORE=$((SCORE+2)); log "✔ Partisi ${DISK}2 ditemukan"
else
    log "✘ Partisi ${DISK}2 tidak ada"
fi

if check_remote "lsblk ${DISK}3 2>/dev/null"; then
    SCORE=$((SCORE+2)); log "✔ Partisi ${DISK}3 ditemukan"
else
    log "✘ Partisi ${DISK}3 tidak ada"
fi

if check_remote "blkid ${DISK}1 | grep -q 'TYPE=\"ext4\"'"; then
    SCORE=$((SCORE+2)); log "✔ ${DISK}1 berformat ext4"
else
    log "✘ ${DISK}1 BUKAN ext4 (atau belum diformat)"
fi

if check_remote "blkid ${DISK}2 | grep -q 'TYPE=\"ext4\"'"; then
    SCORE=$((SCORE+2)); log "✔ ${DISK}2 berformat ext4"
else
    log "✘ ${DISK}2 BUKAN ext4 (atau belum diformat)"
fi

log "==================== LVM ===================="
if check_remote "sudo vgs 2>/dev/null | grep -q vg_sacr"; then
    SCORE=$((SCORE+2)); log "✔ Volume Group 'vg_sacr' ditemukan"
else
    log "✘ Volume Group 'vg_sacr' TIDAK ditemukan"
fi

if check_remote "sudo lvs 2>/dev/null | grep -q lv_logs"; then
    SCORE=$((SCORE+2)); log "✔ Logical Volume 'lv_logs' ditemukan"
else
    log "✘ Logical Volume 'lv_logs' TIDAK ditemukan"
fi

if check_remote "sudo lvs 2>/dev/null | grep -q lv_archive"; then
    SCORE=$((SCORE+2)); log "✔ Logical Volume 'lv_archive' ditemukan"
else
    log "✘ Logical Volume 'lv_archive' TIDAK ditemukan"
fi

log "==================== CEK MOUNT POINT ===================="
for mp in /mnt/app_data /mnt/backup /mnt/logs /mnt/archive; do
    if check_remote "mount | grep -q \"$mp\""; then
        SCORE=$((SCORE+2)); log "✔ Mount point $mp terpasang"
    else
        log "✘ Mount point $mp TIDAK terpasang"
    fi
done

log "==================== CEK FILE UJI ===================="
if check_remote "[ -f /mnt/app_data/app.conf ]"; then
    SCORE=$((SCORE+1)); log "✔ File app.conf ada"
else
    log "✘ app.conf hilang"
fi

if check_remote "[ -f /mnt/backup/backup.tar ]"; then
    SCORE=$((SCORE+1)); log "✔ File backup.tar ada"
else
    log "✘ backup.tar hilang"
fi

if check_remote "[ -f /mnt/logs/access.log ] && [ -f /mnt/logs/error.log ]"; then
    SCORE=$((SCORE+1)); log "✔ File log (access.log & error.log) ada"
else
    log "✘ File log tidak lengkap"
fi

log "==================== CEK OWNER & PERMISSION ===================="
if check_remote "stat -c '%U %G %a' /mnt/app_data 2>/dev/null | grep -q 'root root 755'"; then
    SCORE=$((SCORE+2)); log "✔ /mnt/app_data -> root:root 755"
else
    log "✘ /mnt/app_data salah (harus root:root 755)"
fi

if check_remote "getent group sacr >/dev/null && getent passwd backupuser >/dev/null"; then
    if check_remote "stat -c '%U %G %a' /mnt/backup 2>/dev/null | grep -q 'backupuser sacr 770'"; then
        SCORE=$((SCORE+2)); log "✔ /mnt/backup -> backupuser:sacr 770"
    else
        log "✘ /mnt/backup salah (harus backupuser:sacr 770)"
    fi
else
    log "✘ User 'backupuser' atau group 'sacr' belum dibuat"
fi

if check_remote "getent passwd loguser >/dev/null"; then
    if check_remote "stat -c '%U %G %a' /mnt/logs 2>/dev/null | grep -q 'loguser sacr 775'"; then
        SCORE=$((SCORE+2)); log "✔ /mnt/logs -> loguser:sacr 775"
    else
        log "✘ /mnt/logs salah (harus loguser:sacr 775)"
    fi
else
    log "✘ User 'loguser' belum dibuat"
fi

if check_remote "stat -c '%U %G %a' /mnt/archive 2>/dev/null | grep -q 'root root 755'"; then
    SCORE=$((SCORE+2)); log "✔ /mnt/archive -> root:root 755"
else
    log "✘ /mnt/archive salah (harus root:root 755)"
fi

log "==================== CEK FSTAB ===================="
if check_remote "grep -E '${DISK}1|${DISK}2|vg_sacr' /etc/fstab 2>/dev/null | grep -v '^#'"; then
    SCORE=$((SCORE+2)); log "✔ Entri fstab ditemukan"
else
    log "✘ Tidak ada entri fstab untuk partisi/LV"
fi
###

log "==================== ANSIBLE ===================="
if [ -f /home/sysadmin/ansible/inventory ] && grep -q "$M1" /home/sysadmin/ansible/inventory && grep -q "$M2" /home/sysadmin/ansible/inventory; then SCORE=$((SCORE+3)); log "✔ Inventory OK"; else log "✘ Inventory salah"; fi
if sshpass -p sysadmin ansible all -i /home/sysadmin/ansible/inventory -m ping --ask-pass 2>/dev/null | grep -q "SUCCESS"; then SCORE=$((SCORE+3)); log "✔ Ping berhasil"; else log "✘ Ping gagal"; fi
if check_remote $M1 "id managed 2>/dev/null && getent group cyberranger 2>/dev/null && id managed 2>/dev/null | grep cyberranger" && check_remote $M2 "id managed 2>/dev/null && getent group cyberranger 2>/dev/null"; then SCORE=$((SCORE+4)); log "✔ managed + cyberranger sesuai"; else log "✘ Ansible user/group salah"; fi
if grep -qE '^\s*become:\s*true' /home/sysadmin/ansible/default.yml 2>/dev/null; then SCORE=$((SCORE+1)); log "✔ Sudo prompt aktif"; else log "✘ Tidak ada sudo prompt"; fi

# ==========================================================

log ""
log "==================== HASIL AKHIR ===================="
log "Peserta: $PESERTA"
log "Skor akhir: $SCORE / 100"
log "Waktu Pengerjaan: $WAKTU_PENGERJAAN"

if [ $SCORE -ge 70 ]; then
    STATUS="STATUS: LULUS"
else
    STATUS="STATUS: != LULUS"
fi
log "$STATUS"


# 1. Mengirim ke Google Sheet
curl -s -L -X POST "$GSHEET_WEB_APP_URL" \
-H "Content-Type: application/json" \
-d "{\"name\": \"$PESERTA\", \"SCORE\": $SCORE, \"time\": \"$WAKTU_PENGERJAAN\"}" >/dev/null 2>&1

# 2. Mengirim ke Telegram
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="*Hasil OSC SYSADMIN 2025*\
Peserta: $PESERTA
Skor: $SCORE / 100
Durasi: $WAKTU_PENGERJAAN
Tanggal dan Waktu: $(date +'%d-%m-%Y %H:%M:%S')
$STATUS" \
    -d parse_mode="Markdown" >/dev/null

log ""
log "=== SELESAI ==="
