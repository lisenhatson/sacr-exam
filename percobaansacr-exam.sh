#!/bin/bash

# ==========================================================
# KONFIGURASI
# ==========================================================

GSHEET_WEB_APP_URL="-"

BOT_TOKEN=""
CHAT_ID=""

PESERTA=$(cat /tmp/sacr_peserta.log 2>/dev/null)

if [ -z "$PESERTA" ]; then
    echo "ERROR: Data peserta tidak ditemukan. Jalankan 'sacr start' terlebih dahulu."
    exit 1
fi

SCORE=0
MAX_SCORE=100

M1="machine1.sacr.id"
M2="machine2.sacr.id"

USER="sysadmin"
PASS="sysadmin"

REPORT="/tmp/sacr_report_${PESERTA// /_}.txt"
TIME_LOG="/tmp/sacr_start_time.log"

touch "$REPORT"

# ==========================================================
# FUNGSI
# ==========================================================

log() {
    echo -e "$1" | tee -a "$REPORT"
}

check_remote() {
    sshpass -p "$PASS" ssh -q \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=5 \
        "$USER@$1" "$2" 2>/dev/null
}

# ==========================================================
# DETEKSI DISK
# ==========================================================

ROOT_DISK=$(df / | awk 'NR==2 {print $1}' | sed 's/[0-9]*$//' | xargs basename)

if [ -z "$ROOT_DISK" ]; then
    ROOT_DISK=$(lsblk -n -o NAME,MOUNTPOINT | grep -w '/' | awk '{print $1}' | sed 's/[0-9]*$//')
fi

if [ -z "$ROOT_DISK" ]; then
    log "ERROR: Tidak dapat menentukan root disk."
    exit 1
fi

TEST_DISK=$(lsblk -nd -o NAME,TYPE | grep disk | awk '{print $1}' | grep -v "$ROOT_DISK" | head -n1)

if [ -z "$TEST_DISK" ]; then
    if [ -b /dev/vdb ]; then
        TEST_DISK="vdb"
    elif [ -b /dev/sdb ]; then
        TEST_DISK="sdb"
    else
        log "ERROR: Disk tambahan tidak ditemukan."
        exit 1
    fi
fi

DISK="/dev/$TEST_DISK"

log "Disk yang terdeteksi: $DISK"

# ==========================================================
# DURASI
# ==========================================================

if [ -f "$TIME_LOG" ]; then

    START_TIME=$(cat "$TIME_LOG")
    END_TIME=$(date +%s)

    TOTAL_SECONDS=$((END_TIME - START_TIME))

    MINUTES=$((TOTAL_SECONDS / 60))
    SECONDS=$((TOTAL_SECONDS % 60))

    DURASI_PENGERJAAN="${MINUTES} menit ${SECONDS} detik"

    rm -f "$TIME_LOG"

else

    DURASI_PENGERJAAN="Tidak tercatat"

fi

# ==========================================================
# HEADER REPORT
# ==========================================================

log ""
log "=== SACR SYSADMIN REPORT ==="
log "Peserta : $PESERTA"
log "Tanggal : $(date '+%d-%m-%Y %H:%M:%S')"
log "Durasi  : $DURASI_PENGERJAAN"
log ""

# ==========================================================
# BASIC CONFIGURATION
# ==========================================================

log "==================== BASIC CONFIGURATION ===================="

if check_remote $M1 "hostnamectl | grep -q 'machine1.sacr.id'" && \
   check_remote $M2 "hostnamectl | grep -q 'machine2.sacr.id'"
then
    SCORE=$((SCORE+2))
    log "✔ Hostname sesuai"
else
    log "✘ Hostname salah"
fi

if check_remote $M1 "grep -q '^PermitRootLogin no' /etc/ssh/sshd_config" && \
   check_remote $M2 "grep -q '^PermitRootLogin no' /etc/ssh/sshd_config"
then
    SCORE=$((SCORE+2))
    log "✔ SSH non-root login OK"
else
    log "✘ SSH belum diset non-root"
fi

# ==========================================================
# LINUX FUNDAMENTAL
# ==========================================================

log "==================== LINUX FUNDAMENTAL ===================="

if check_remote $M1 "[ -d ~/ujian_sacr ] && [ -f ~/ujian_sacr/audit.sh ]"; then SCORE=$((SCORE+1)); log "✔ Folder ujian_sacr dan audit.sh ada"; else log "✘ Folder ujian_sacr atau audit.sh tidak ada"; fi
if check_remote $M1 "[ \"\$(stat -c '%a' ~/ujian_sacr/audit.sh)\" = '750' ]"; then SCORE=$((SCORE+1)); log "✔ Permission audit.sh benar"; else log "✘ Permission audit.sh salah"; fi
if check_remote $M1 "getent group cyber >/dev/null"; then SCORE=$((SCORE+1)); log "✔ Group cyber ada"; else log "✘ Group cyber belum ada"; fi
if check_remote $M1 "id analyst 2>/dev/null | grep -q cyber"; then SCORE=$((SCORE+1)); log "✔ User analyst sesuai"; else log "✘ User analyst belum sesuai"; fi
if check_remote $M1 "[ -d ~/projek_linux ]"; then SCORE=$((SCORE+1)); log "✔ Direktori projek_linux ada"; else log "✘ Direktori projek_linux belum ada"; fi
if check_remote $M1 "[ -f ~/projek_linux/readme.txt ] && [ -f ~/projek_linux/config.txt ]"; then SCORE=$((SCORE+1)); log "✔ File projek_linux lengkap"; else log "✘ File projek_linux belum lengkap"; fi
if check_remote $M1 "[ -f ~/projek_linux/readme_backup.txt ]"; then SCORE=$((SCORE+1)); log "✔ Backup file berhasil dibuat"; else log "✘ Backup file belum dibuat"; fi
if check_remote $M1 "[ -f ~/arsip/laporan_final.txt ]"; then SCORE=$((SCORE+1)); log "✔ laporan_final.txt ditemukan"; else log "✘ laporan_final.txt tidak ditemukan"; fi
if check_remote $M1 "getent group tim_it >/dev/null"; then SCORE=$((SCORE+1)); log "✔ Group tim_it ada"; else log "✘ Group tim_it belum ada"; fi
if check_remote $M1 "id operator01 2>/dev/null | grep -q tim_it"; then SCORE=$((SCORE+1)); log "✔ User operator01 sesuai"; else log "✘ User operator01 belum sesuai"; fi

# ==========================================================
# SERVER FUNDAMENTAL
# ==========================================================

log "==================== SERVER FUNDAMENTAL ===================="

if check_remote $M1 "[ -f ~/.ssh/ujian_key ] && [ -f ~/.ssh/ujian_key.pub ]"; then SCORE=$((SCORE+2)); log "✔ SSH key ujian_key ada"; else log "✘ SSH key belum dibuat"; fi
if check_remote $M1 "systemctl is-active ssh | grep -q active"; then SCORE=$((SCORE+1)); log "✔ Service SSH aktif"; else log "✘ Service SSH tidak aktif"; fi
if check_remote $M1 "systemctl is-active mariadb | grep -q active"; then SCORE=$((SCORE+2)); log "✔ MariaDB aktif"; else log "✘ MariaDB tidak aktif"; fi
if check_remote $M1 "sudo mariadb -e \"SELECT User FROM mysql.user\" | grep -q user_ujian"; then SCORE=$((SCORE+2)); log "✔ User MariaDB ditemukan"; else log "✘ User MariaDB belum dibuat"; fi
if check_remote $M1 "systemctl is-active nginx | grep -q active"; then SCORE=$((SCORE+2)); log "✔ Nginx aktif"; else log "✘ Nginx tidak aktif"; fi
if check_remote $M1 "sudo nginx -T 2>/dev/null | grep -q 'listen 8080'"; then SCORE=$((SCORE+2)); log "✔ Nginx listen 8080"; else log "✘ Konfigurasi nginx salah"; fi
if check_remote $M1 "curl localhost:8080 >/dev/null 2>&1"; then SCORE=$((SCORE+2)); log "✔ Website dapat diakses"; else log "✘ Website tidak dapat diakses"; fi
if check_remote $M1 "sudo ufw status | grep -q '22/tcp'"; then SCORE=$((SCORE+1)); log "✔ Rule SSH ada"; else log "✘ Rule SSH tidak ditemukan"; fi
if check_remote $M1 "sudo ufw status | grep -q '8080'"; then SCORE=$((SCORE+1)); log "✔ Rule 8080 ada"; else log "✘ Rule 8080 tidak ditemukan"; fi
if check_remote $M1 "sudo ufw status | grep -q '3306'"; then SCORE=$((SCORE+1)); log "✔ Rule 3306 ada"; else log "✘ Rule 3306 tidak ditemukan"; fi

# ==========================================================
# DOCKER
# ==========================================================

log "==================== DOCKER ===================="

if check_remote $M2 "[ -f Dockerfile ]"; then
    SCORE=$((SCORE+1))
    log "✔ Dockerfile ditemukan"
else
    log "✘ Dockerfile tidak ditemukan"
fi

if check_remote $M2 "[ -f app.py ]"; then
    SCORE=$((SCORE+1))
    log "✔ app.py ditemukan"
else
    log "✘ app.py tidak ditemukan"
fi

if check_remote $M2 "docker image ls | awk 'NR>1' | grep -q ."; then
    SCORE=$((SCORE+2))
    log "✔ Minimal satu image Docker ditemukan"
else
    log "✘ Tidak ada image Docker"
fi

if check_remote $M2 "
docker images --format '{{.Repository}}' |
while read img; do
docker run --rm \$img 2>/dev/null
done | grep -q 'Hello From Docker Container'
"; then
    SCORE=$((SCORE+3))
    log "✔ Container Python berhasil dijalankan"
else
    log "✘ Output Hello From Docker Container tidak ditemukan"
fi

if check_remote $M2 "curl http://localhost:8080 >/dev/null 2>&1"; then
    SCORE=$((SCORE+3))
    log "✔ Container nginx dapat diakses"
else
    log "✘ Container nginx tidak dapat diakses"
fi

# ==========================================================
# PUBLIC KEY INFRASTRUCTURE
# ==========================================================

log "==================== PUBLIC KEY INFRASTRUCTURE ===================="

log "==================== PUBLIC KEY INFRASTRUCTURE ===================="

# ROOT CA

if check_remote $M1 "[ -f rootCA.key ]"; then
    SCORE=$((SCORE+1))
    log "✔ rootCA.key ditemukan"
else
    log "✘ rootCA.key tidak ditemukan"
fi

if check_remote $M1 "[ -f rootCA.crt ]"; then
    SCORE=$((SCORE+1))
    log "✔ rootCA.crt ditemukan"
else
    log "✘ rootCA.crt tidak ditemukan"
fi

if check_remote $M1 "openssl x509 -in rootCA.crt -noout -subject 2>/dev/null | grep -Eq 'CN ?= ?SACR Root CA|SACR Root CA'"; then
    SCORE=$((SCORE+1))
    log "✔ Subject Root CA benar"
else
    log "✘ Subject Root CA salah"
fi

if check_remote $M1 "openssl x509 -in rootCA.crt -noout -issuer 2>/dev/null | grep -Eq 'CN ?= ?SACR Root CA|SACR Root CA'"; then
    SCORE=$((SCORE+1))
    log "✔ Issuer Root CA benar"
else
    log "✘ Issuer Root CA salah"
fi

# INTERMEDIATE CA

if check_remote $M1 "[ -f intermediateCA.key ]"; then
    SCORE=$((SCORE+1))
    log "✔ intermediateCA.key ditemukan"
else
    log "✘ intermediateCA.key tidak ditemukan"
fi

if check_remote $M1 "[ -f intermediateCA.csr ]"; then
    SCORE=$((SCORE+1))
    log "✔ intermediateCA.csr ditemukan"
else
    log "✘ intermediateCA.csr tidak ditemukan"
fi

if check_remote $M1 "[ -f intermediateCA.crt ]"; then
    SCORE=$((SCORE+1))
    log "✔ intermediateCA.crt ditemukan"
else
    log "✘ intermediateCA.crt tidak ditemukan"
fi

if check_remote $M1 "openssl x509 -in intermediateCA.crt -noout -subject 2>/dev/null | grep -Eq 'CN ?= ?SACR Intermediate CA|SACR Intermediate CA'"; then
    SCORE=$((SCORE+1))
    log "✔ Subject Intermediate CA benar"
else
    log "✘ Subject Intermediate CA salah"
fi

if check_remote $M1 "openssl x509 -in intermediateCA.crt -noout -issuer 2>/dev/null | grep -Eq 'CN ?= ?SACR Root CA|SACR Root CA'"; then
    SCORE=$((SCORE+1))
    log "✔ Issuer Intermediate CA benar"
else
    log "✘ Issuer Intermediate CA salah"
fi

# SERVER CERTIFICATE

if check_remote $M1 "[ -f server.key ]"; then
    SCORE=$((SCORE+1))
    log "✔ server.key ditemukan"
else
    log "✘ server.key tidak ditemukan"
fi

if check_remote $M1 "[ -f server.csr ]"; then
    SCORE=$((SCORE+1))
    log "✔ server.csr ditemukan"
else
    log "✘ server.csr tidak ditemukan"
fi

if check_remote $M1 "[ -f server.crt ]"; then
    SCORE=$((SCORE+1))
    log "✔ server.crt ditemukan"
else
    log "✘ server.crt tidak ditemukan"
fi

if check_remote $M1 "openssl x509 -in server.crt -noout -subject 2>/dev/null | grep -Eq 'CN ?= ?server.sacr.local|server.sacr.local'"; then
    SCORE=$((SCORE+2))
    log "✔ Subject Server benar"
else
    log "✘ Subject Server salah"
fi

if check_remote $M1 "openssl x509 -in server.crt -noout -issuer 2>/dev/null | grep -Eq 'CN ?= ?SACR Intermediate CA|SACR Intermediate CA'"; then
    SCORE=$((SCORE+2))
    log "✔ Issuer Server benar"
else
    log "✘ Issuer Server salah"
fi

# FULLCHAIN

if check_remote $M1 "[ -f fullchain.pem ]"; then
    SCORE=$((SCORE+1))
    log "✔ fullchain.pem ditemukan"
else
    log "✘ fullchain.pem tidak ditemukan"
fi

# CHAIN VALIDATION

if check_remote $M1 "openssl verify -CAfile rootCA.crt -untrusted intermediateCA.crt server.crt 2>/dev/null | grep -q ': OK'"; then
    SCORE=$((SCORE+3))
    log "✔ Chain of Trust valid"
else
    log "✘ Chain of Trust gagal"
fi

# ==========================================================
# PARTISI & FILESYSTEM
# ==========================================================

log "==================== PARTISI & FILESYSTEM ===================="

if check_remote $M1 "lsblk ${DISK}1 >/dev/null 2>&1"; then
    SCORE=$((SCORE+1))
    log "✔ Partisi ${DISK}1 ditemukan"
else
    log "✘ Partisi ${DISK}1 tidak ditemukan"
fi

if check_remote $M1 "lsblk ${DISK}2 >/dev/null 2>&1"; then
    SCORE=$((SCORE+1))
    log "✔ Partisi ${DISK}2 ditemukan"
else
    log "✘ Partisi ${DISK}2 tidak ditemukan"
fi

if check_remote $M1 "lsblk ${DISK}3 >/dev/null 2>&1"; then
    SCORE=$((SCORE+1))
    log "✔ Partisi ${DISK}3 ditemukan"
else
    log "✘ Partisi ${DISK}3 tidak ditemukan"
fi

if check_remote $M1 "blkid ${DISK}1 | grep -q 'TYPE=\"ext4\"'"; then
    SCORE=$((SCORE+1))
    log "✔ ${DISK}1 ext4"
else
    log "✘ ${DISK}1 bukan ext4"
fi

if check_remote $M1 "blkid ${DISK}2 | grep -q 'TYPE=\"ext4\"'"; then
    SCORE=$((SCORE+1))
    log "✔ ${DISK}2 ext4"
else
    log "✘ ${DISK}2 bukan ext4"
fi

log "==================== LVM ===================="

if check_remote $M1 "sudo vgs | grep -q vg_sacr"; then
    SCORE=$((SCORE+1))
    log "✔ VG vg_sacr ditemukan"
else
    log "✘ VG vg_sacr tidak ditemukan"
fi

if check_remote $M1 "sudo lvs | grep -q lv_logs"; then
    SCORE=$((SCORE+1))
    log "✔ LV lv_logs ditemukan"
else
    log "✘ LV lv_logs tidak ditemukan"
fi

if check_remote $M1 "sudo lvs | grep -q lv_archive"; then
    SCORE=$((SCORE+1))
    log "✔ LV lv_archive ditemukan"
else
    log "✘ LV lv_archive tidak ditemukan"
fi

log "==================== CEK MOUNT POINT ===================="

for mp in /mnt/app_data /mnt/backup /mnt/logs /mnt/archive
do
    if check_remote $M1 "mount | grep -q '$mp'"
    then
        SCORE=$((SCORE+1))
        log "✔ Mount point $mp terpasang"
    else
        log "✘ Mount point $mp tidak terpasang"
    fi
done

# ==========================================================
# CEK FILE UJI
# ==========================================================

log "==================== CEK FILE UJI ===================="

if check_remote $M1 "[ -f /mnt/app_data/app.conf ]"
then
    SCORE=$((SCORE+1))
    log "✔ app.conf ditemukan"
else
    log "✘ app.conf tidak ditemukan"
fi

if check_remote $M1 "[ -f /mnt/backup/backup.tar ]"
then
    SCORE=$((SCORE+1))
    log "✔ backup.tar ditemukan"
else
    log "✘ backup.tar tidak ditemukan"
fi

if check_remote $M1 "[ -f /mnt/logs/access.log ] && [ -f /mnt/logs/error.log ]"
then
    SCORE=$((SCORE+1))
    log "✔ File log lengkap"
else
    log "✘ File log tidak lengkap"
fi

# ==========================================================
# CEK OWNER & PERMISSION
# ==========================================================

log "==================== CEK OWNER & PERMISSION ===================="

if check_remote $M1 "stat -c '%U %G %a' /mnt/app_data 2>/dev/null | grep -q '^root root 755$'"
then
    SCORE=$((SCORE+1))
    log "✔ /mnt/app_data sesuai"
else
    log "✘ Permission /mnt/app_data salah"
fi

if check_remote $M1 "getent passwd backupuser >/dev/null && getent group sacr >/dev/null"
then
    if check_remote $M1 "stat -c '%U %G %a' /mnt/backup 2>/dev/null | grep -q '^backupuser sacr 770$'"
    then
        SCORE=$((SCORE+1))
        log "✔ /mnt/backup sesuai"
    else
        log "✘ Permission /mnt/backup salah"
    fi
else
    log "✘ backupuser atau group sacr tidak ditemukan"
fi

if check_remote $M1 "getent passwd loguser >/dev/null"
then
    if check_remote $M1 "stat -c '%U %G %a' /mnt/logs 2>/dev/null | grep -q '^loguser sacr 775$'"
    then
        SCORE=$((SCORE+1))
        log "✔ /mnt/logs sesuai"
    else
        log "✘ Permission /mnt/logs salah"
    fi
else
    log "✘ User loguser tidak ditemukan"
fi

if check_remote $M1 "stat -c '%U %G %a' /mnt/archive 2>/dev/null | grep -q '^root root 755$'"
then
    SCORE=$((SCORE+1))
    log "✔ /mnt/archive sesuai"
else
    log "✘ Permission /mnt/archive salah"
fi

# ==========================================================
# CEK FSTAB
# ==========================================================

log "==================== CEK FSTAB ===================="

if check_remote $M1 "grep -Ev '^#|^$' /etc/fstab | grep -Eq '${DISK}1|${DISK}2|vg_sacr'"
then
    SCORE=$((SCORE+2))
    log "✔ Entri fstab ditemukan"
else
    log "✘ Entri fstab tidak ditemukan"
fi

# ==========================================================
# ANSIBLE
# ==========================================================

log "==================== ANSIBLE ===================="

if [ -f /home/sysadmin/ansible/inventory ] \
&& grep -q "$M1" /home/sysadmin/ansible/inventory \
&& grep -q "$M2" /home/sysadmin/ansible/inventory
then
    SCORE=$((SCORE+2))
    log "✔ Inventory sesuai"
else
    log "✘ Inventory tidak sesuai"
fi

if sshpass -p "$PASS" ansible all \
-i /home/sysadmin/ansible/inventory \
-m ping \
--ask-pass 2>/dev/null | grep -q SUCCESS
then
    SCORE=$((SCORE+2))
    log "✔ Ansible ping berhasil"
else
    log "✘ Ansible ping gagal"
fi

if check_remote $M1 "id managed 2>/dev/null | grep -q cyberranger" && \
   check_remote $M2 "id managed 2>/dev/null | grep -q cyberranger"
then
    SCORE=$((SCORE+2))
    log "✔ User managed dan group cyberranger sesuai"
else
    log "✘ Konfigurasi managed/cyberranger salah"
fi

if grep -qE '^[[:space:]]*become:[[:space:]]*true' /home/sysadmin/ansible/default.yml 2>/dev/null
then
    SCORE=$((SCORE+1))
    log "✔ become:true ditemukan"
else
    log "✘ become:true tidak ditemukan"
fi

# ==========================================================
# HASIL AKHIR
# ==========================================================

PERCENT=$(( SCORE * 100 / MAX_SCORE ))

log ""
log "==================== HASIL AKHIR ===================="
log "Peserta            : $PESERTA"
log "Skor               : $SCORE / $MAX_SCORE"
log "Persentase         : ${PERCENT}%"
log "Durasi Pengerjaan  : $DURASI_PENGERJAAN"

if [ "$PERCENT" -ge 70 ]
then
    STATUS="STATUS: LULUS"
else
    STATUS="STATUS: TIDAK LULUS"
fi

log "$STATUS"

# ==========================================================
# KIRIM GOOGLE SHEET
# ==========================================================

curl -s -L -X POST "$GSHEET_WEB_APP_URL" \
-H "Content-Type: application/json" \
-d "{\"name\":\"$PESERTA\",\"score\":$SCORE,\"percent\":$PERCENT,\"duration\":\"$DURASI_PENGERJAAN\"}" \
>/dev/null 2>&1

# ==========================================================
# KIRIM TELEGRAM SUMMARY
# ==========================================================

curl -s -X POST \
"https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
-d chat_id="$CHAT_ID" \
-d parse_mode="Markdown" \
-d text="*Hasil Ujian SACR*

Peserta : $PESERTA
Skor    : $SCORE / $MAX_SCORE
Nilai   : ${PERCENT}%
Durasi  : $DURASI_PENGERJAAN

$STATUS" \
>/dev/null

# ==========================================================
# KIRIM FILE REPORT
# ==========================================================

curl -s -X POST \
"https://api.telegram.org/bot$BOT_TOKEN/sendDocument" \
-F chat_id="$CHAT_ID" \
-F document=@"$REPORT" \
>/dev/null

log ""
log "=== SELESAI ==="

