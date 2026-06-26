#!/bin/bash

# ==========================================================
# KONFIGURASI
# ==========================================================

GSHEET_WEB_APP_URL="-"

BOT_TOKEN=8990919507:AAFonVLoiBdTo6wT3uGW33Z8hYqoGQ_bIVw
CHAT_ID=8377686974

PESERTA=$1

if [ -z "$PESERTA" ]; then
    echo "ERROR: Data peserta tidak ditemukan. Jalankan 'sacr start' terlebih dahulu."
    exit 1
fi

DISK="/dev/vdb"

SCORE=0
MAX_SCORE=100

M1="machine1.sacr.id"
M2="machine2.sacr.id"

USER="sacr"
PASS="sacr2026"

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
log "=== SACR sacr REPORT ==="
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
    SCORE=$((SCORE+3))
    log "✔ SSH non-root login OK"
else
    log "✘ SSH belum diset non-root"
fi

# ==========================================================
# LINUX FUNDAMENTAL
# ==========================================================

log "==================== LINUX FUNDAMENTAL ===================="

if check_remote $M1 "[ -d ~/ujian_sacr ] && [ -f ~/ujian_sacr/audit.sh ] && [ -s ~/ujian_sacr/audit.sh ]"; then SCORE=$((SCORE+1)); log "✔ Soal 1 benar"; else log "✘ Soal 1 salah"; fi
if check_remote $M1 "[ \"\$(stat -c '%a' ~/ujian_sacr/audit.sh)\" = '740' ]"; then SCORE=$((SCORE+1)); log "✔ Soal 2 benar"; else log "✘ Soal 2 salah"; fi
if check_remote $M1 "getent group cyber >/dev/null && id analyst 2>/dev/null | grep -qw cyber"; then SCORE=$((SCORE+1)); log "✔ Soal 3 benar"; else log "✘ Soal 3 salah"; fi
if check_remote $M1 "[ -d ~/projek_linux ] && [ -f ~/projek_linux/readme.txt ] && [ -f ~/projek_linux/config.txt ] && [ -f ~/projek_linux/readme_backup.txt ] && cmp -s ~/projek_linux/readme.txt ~/projek_linux/readme_backup.txt"; then SCORE=$((SCORE+1)); log "✔ Soal 4 benar"; else log "✘ Soal 4 salah"; fi
if check_remote $M1 "[ -f ~/arsip/laporan_final.txt ] && [ ! -f ~/laporan.txt ]"; then SCORE=$((SCORE+1)); log "✔ Soal 5 benar"; else log "✘ Soal 5 salah"; fi
if check_remote $M1 "getent group tim_it >/dev/null && id operator01 2>/dev/null | grep -qw tim_it"; then SCORE=$((SCORE+1)); log "✔ Soal 6 benar"; else log "✘ Soal 6 salah"; fi

# ==========================================================
# SERVER FUNDAMENTAL
# ==========================================================

log "==================== SERVER FUNDAMENTAL ===================="

# Soal 1
if check_remote $M1 "[ -f ~/.ssh/ujian_key ] && [ -f ~/.ssh/ujian_key.pub ] && ssh-keygen -lf ~/.ssh/ujian_key.pub >/dev/null 2>&1"; then SCORE=$((SCORE+1)); log "✔ SSH key valid"; else log "✘ SSH key belum valid"; fi

# Soal 2
if check_remote $M1 "systemctl is-active --quiet mariadb"; then SCORE=$((SCORE+1)); log "✔ MariaDB aktif"; else log "✘ MariaDB tidak aktif"; fi

output=$(check_remote $M1 "echo $PASS | sudo -S mariadb -e \"SHOW GRANTS FOR 'user_ujian'@'localhost';\"")

if echo "$output" | grep -q SELECT; then
    SCORE=$((SCORE+1))
    log "✔ User MariaDB sesuai"
else
    log "✘ User MariaDB belum sesuai"
fi

# Soal 3
if check_remote $M1 "systemctl is-active --quiet nginx"; then SCORE=$((SCORE+1)); log "✔ Nginx aktif"; else log "✘ Nginx tidak aktif"; fi
if check_remote $M1 "echo $PASS | sudo -S nginx -T 2>/dev/null | grep -q 'listen 8080'"; then SCORE=$((SCORE+1)); log "✔ Nginx listen 8080"; else log "✘ Konfigurasi Nginx salah"; fi
if check_remote $M1 "curl -s http://localhost:8080 >/dev/null"; then SCORE=$((SCORE+1)); log "✔ Website dapat diakses"; else log "✘ Website tidak dapat diakses"; fi

# Soal 4
if check_remote $M1 "echo $PASS | sudo -S ufw status | grep -q 'Status: active'"; then SCORE=$((SCORE+1)); log "✔ UFW aktif"; else log "✘ UFW belum aktif"; fi
if check_remote $M1 "echo $PASS | sudo -S ufw status | grep -Eq '22/tcp.*ALLOW'"; then SCORE=$((SCORE+1)); log "✔ Rule SSH sesuai"; else log "✘ Rule SSH tidak sesuai"; fi
if check_remote $M1 "echo $PASS | sudo -S ufw status | grep -Eq '8080(/tcp)?[[:space:]]+ALLOW.*127\.0\.0\.1'"; then SCORE=$((SCORE+1)); log "✔ Rule localhost:8080 sesuai"; else log "✘ Rule localhost:8080 tidak sesuai"; fi
if check_remote $M1 "echo $PASS | sudo -S ufw status | grep -Eq '3306(/tcp)?.*DENY'"; then SCORE=$((SCORE+1)); log "✔ Rule MariaDB sesuai"; else log "✘ Rule MariaDB tidak sesuai"; fi

# ==========================================================
# DOCKER
# ==========================================================

log "==================== DOCKER ===================="

if check_remote $M2 "grep -q '^FROM' Dockerfile"; then SCORE=$((SCORE+1)); log "✔ Dockerfile valid"; else log "✘ Dockerfile tidak valid"; fi
if check_remote $M2 "grep -q 'Hello From Docker Container' app.py"; then SCORE=$((SCORE+1)); log "✔ app.py sesuai"; else log "✘ app.py tidak sesuai"; fi
if check_remote $M2 "docker image inspect python-demo >/dev/null 2>&1"; then SCORE=$((SCORE+2)); log "✔ Image python-demo ditemukan"; else log "✘ Image python-demo tidak ditemukan"; fi
if check_remote $M2 "docker run --rm python-demo 2>/dev/null | grep -q 'Hello From Docker Container'"; then SCORE=$((SCORE+3)); log "✔ Output container benar"; else log "✘ Output container salah"; fi
if check_remote $M2 "docker ps --format '{{.Names}}' | grep -q '^sacr-nginx$'"; then SCORE=$((SCORE+2)); log "✔ Container nginx berjalan"; else log "✘ Container nginx tidak berjalan"; fi
if check_remote $M2 "curl -s http://localhost:8080 | grep -qi nginx"; then SCORE=$((SCORE+3)); log "✔ Nginx container dapat diakses"; else log "✘ Nginx container tidak dapat diakses"; fi

# ==========================================================
# PUBLIC KEY INFRASTRUCTURE
# ==========================================================

log "==================== PUBLIC KEY INFRASTRUCTURE ===================="

# ================= ROOT CA =================
if check_remote $M1 "openssl x509 -in rootCA.crt -noout -subject 2>/dev/null | grep -Eq 'CN ?= ?SACR Root CA|SACR Root CA'"; then SCORE=$((SCORE+1)); log "✔ Subject Root CA benar"; else log "✘ Subject Root CA salah"; fi
if check_remote $M1 "openssl x509 -in rootCA.crt -noout -issuer 2>/dev/null | grep -Eq 'CN ?= ?SACR Root CA|SACR Root CA'"; then SCORE=$((SCORE+1)); log "✔ Issuer Root CA benar"; else log "✘ Issuer Root CA salah"; fi
if check_remote $M1 "openssl x509 -in rootCA.crt -text -noout 2>/dev/null | grep -q 'CA:TRUE'"; then SCORE=$((SCORE+1)); log '✔ Root CA memiliki CA:TRUE'; else log '✘ Root CA bukan Certificate Authority'; fi

# ================= INTERMEDIATE CA =================

if check_remote $M1 "openssl x509 -in intermediateCA.crt -noout -subject 2>/dev/null | grep -Eq 'CN ?= ?SACR Intermediate CA|SACR Intermediate CA'"; then SCORE=$((SCORE+1)); log "✔ Subject Intermediate CA benar"; else log "✘ Subject Intermediate CA salah"; fi
if check_remote $M1 "openssl x509 -in intermediateCA.crt -noout -issuer 2>/dev/null | grep -Eq 'CN ?= ?SACR Root CA|SACR Root CA'"; then SCORE=$((SCORE+1)); log "✔ Issuer Intermediate CA benar"; else log "✘ Issuer Intermediate CA salah"; fi
if check_remote $M1 "openssl verify -CAfile rootCA.crt intermediateCA.crt 2>/dev/null | grep -q ': OK'"; then SCORE=$((SCORE+2)); log "✔ Intermediate CA ditandatangani Root CA"; else log "✘ Intermediate CA tidak valid"; fi

# ================= SERVER CERTIFICATE =================

if check_remote $M1 "openssl x509 -in server.crt -noout -subject 2>/dev/null | grep -Eq 'CN ?= ?server.sacr.local|server.sacr.local'"; then SCORE=$((SCORE+1)); log "✔ Subject Server benar"; else log "✘ Subject Server salah"; fi
if check_remote $M1 "openssl x509 -in server.crt -noout -issuer 2>/dev/null | grep -Eq 'CN ?= ?SACR Intermediate CA|SACR Intermediate CA'"; then SCORE=$((SCORE+1)); log "✔ Issuer Server benar"; else log "✘ Issuer Server salah"; fi

# ================= FULL CHAIN =================
if check_remote $M1 "grep -c 'BEGIN CERTIFICATE' fullchain.pem 2>/dev/null | grep -q '^3$'"; then SCORE=$((SCORE+2)); log "✔ fullchain.pem berisi 3 sertifikat"; else log "✘ fullchain.pem tidak lengkap"; fi
if check_remote $M1 "openssl verify -CAfile rootCA.crt -untrusted intermediateCA.crt server.crt 2>/dev/null | grep -q ': OK'"; then SCORE=$((SCORE+4)); log "✔ Chain of Trust valid"; else log "✘ Chain of Trust gagal"; fi


# ==========================================================
# PARTISI & FILESYSTEM
# ==========================================================

log "==================== PARTISI & FILESYSTEM ===================="

if check_remote $M2 "lsblk ${DISK}1 >/dev/null 2>&1"; then SCORE=$((SCORE+1)); log "✔ Partisi ${DISK}1 ditemukan"; else log "✘ Partisi ${DISK}1 tidak ditemukan"; fi
if check_remote $M2 "lsblk ${DISK}2 >/dev/null 2>&1"; then SCORE=$((SCORE+1)); log "✔ Partisi ${DISK}2 ditemukan"; else log "✘ Partisi ${DISK}2 tidak ditemukan"; fi
if check_remote $M2 "lsblk ${DISK}3 >/dev/null 2>&1"; then SCORE=$((SCORE+1)); log "✔ Partisi ${DISK}3 ditemukan"; else log "✘ Partisi ${DISK}3 tidak ditemukan"; fi
if check_remote $M2 "lsblk -b -o SIZE ${DISK}1 | tail -1 | awk '{if(\$1>=190000000 && \$1<=210000000) exit 0; else exit 1}'"; then SCORE=$((SCORE+1)); log "✔ Ukuran ${DISK}1 sesuai (~200MB)"; else log "✘ Ukuran ${DISK}1 tidak sesuai"; fi
if check_remote $M2 "lsblk -b -o SIZE ${DISK}2 | tail -1 | awk '{if(\$1>=290000000 && \$1<=310000000) exit 0; else exit 1}'"; then SCORE=$((SCORE+1)); log "✔ Ukuran ${DISK}2 sesuai (~300MB)"; else log "✘ Ukuran ${DISK}2 tidak sesuai"; fi
if check_remote $M2 "echo $PASS | sudo -S blkid ${DISK}1 | grep -q 'TYPE=\"ext4\"'"; then SCORE=$((SCORE+1)); log "✔ ${DISK}1 ext4"; else log "✘ ${DISK}1 bukan ext4"; fi
if check_remote $M2 "echo $PASS | sudo -S blkid ${DISK}2 | grep -q 'TYPE=\"ext4\"'"; then SCORE=$((SCORE+1)); log "✔ ${DISK}2 ext4"; else log "✘ ${DISK}2 bukan ext4"; fi


log "==================== LVM ===================="

if check_remote $M2 "echo $PASS | sudo -S pvs --noheadings -o pv_name,vg_name | grep -q '${DISK}3.*vg_sacr'"; then SCORE=$((SCORE+1)); log "✔ PV ${DISK}3 tergabung ke vg_sacr"; else log "✘ PV vg_sacr tidak sesuai"; fi
if check_remote $M2 "echo $PASS | sudo -S vgs | grep -q '^ *vg_sacr'"; then SCORE=$((SCORE+1)); log "✔ VG vg_sacr ditemukan"; else log "✘ VG vg_sacr tidak ditemukan"; fi
if check_remote $M2 "echo $PASS | sudo -S lvs | grep -q 'lv_logs'"; then SCORE=$((SCORE+1)); log "✔ LV lv_logs ditemukan"; else log "✘ LV lv_logs tidak ditemukan"; fi
if check_remote $M2 "echo $PASS | sudo -S lvs | grep -q 'lv_archive'"; then SCORE=$((SCORE+1)); log "✔ LV lv_archive ditemukan"; else log "✘ LV lv_archive tidak ditemukan"; fi
if check_remote $M2 "echo $PASS | sudo -S lvs --units m --noheadings -o lv_name,lv_size | grep -E 'lv_logs.*200'"; then SCORE=$((SCORE+1)); log "✔ Ukuran lv_logs sesuai (200MB)"; else log "✘ Ukuran lv_logs tidak sesuai"; fi
if check_remote $M2 "echo $PASS | sudo -S blkid /dev/vg_sacr/lv_logs 2>/dev/null | grep -q 'TYPE=\"ext4\"'"; then SCORE=$((SCORE+1)); log "✔ lv_logs menggunakan ext4"; else log "✘ lv_logs belum diformat ext4"; fi
if check_remote $M2 "echo $PASS | sudo -S blkid /dev/vg_sacr/lv_archive 2>/dev/null | grep -q 'TYPE=\"ext4\"'"; then SCORE=$((SCORE+1)); log "✔ lv_archive menggunakan ext4"; else log "✘ lv_archive belum diformat ext4"; fi


log "==================== CEK MOUNT POINT ===================="

if check_remote $M2 "findmnt -n -o SOURCE /mnt/app_data | grep -q '${DISK}1'"; then SCORE=$((SCORE+1)); log "✔ /mnt/app_data mount dari ${DISK}1"; else log "✘ Mount /mnt/app_data salah"; fi
if check_remote $M2 "findmnt -n -o SOURCE /mnt/backup | grep -q '${DISK}2'"; then SCORE=$((SCORE+1)); log "✔ /mnt/backup mount dari ${DISK}2"; else log "✘ Mount /mnt/backup salah"; fi
if check_remote $M2 "findmnt -n -o SOURCE /mnt/logs | grep -q 'vg_sacr-lv_logs'"; then SCORE=$((SCORE+1)); log "✔ /mnt/logs mount dari lv_logs"; else log "✘ Mount /mnt/logs salah"; fi
if check_remote $M2 "findmnt -n -o SOURCE /mnt/archive | grep -q 'vg_sacr-lv_archive'"; then SCORE=$((SCORE+1)); log "✔ /mnt/archive mount dari lv_archive"; else log "✘ Mount /mnt/archive salah"; fi


log "==================== CEK FILE UJI ===================="

if check_remote $M2 "grep -qx 'server=production' /mnt/app_data/app.conf 2>/dev/null"; then SCORE=$((SCORE+1)); log "✔ app.conf sesuai"; else log "✘ Isi app.conf tidak sesuai"; fi
if check_remote $M2 "[ -f /mnt/backup/backup.tar ]"; then SCORE=$((SCORE+1)); log "✔ backup.tar ditemukan"; else log "✘ backup.tar tidak ditemukan"; fi
if check_remote $M2 "[ -f /mnt/logs/access.log ] && [ -f /mnt/logs/error.log ]"; then SCORE=$((SCORE+1)); log "✔ File log lengkap"; else log "✘ File log tidak lengkap"; fi


log "==================== CEK OWNER & PERMISSION ===================="

if check_remote $M2 "stat -c '%U %G %a' /mnt/app_data 2>/dev/null | grep -q '^root root 755$'"; then SCORE=$((SCORE+1)); log "✔ /mnt/app_data sesuai"; else log "✘ Permission /mnt/app_data salah"; fi
if check_remote $M2 "stat -c '%U %G %a' /mnt/backup 2>/dev/null | grep -q '^backupuser sacr 770$'"; then SCORE=$((SCORE+1)); log "✔ /mnt/backup sesuai"; else log "✘ Permission /mnt/backup salah"; fi
if check_remote $M2 "stat -c '%U %G %a' /mnt/logs 2>/dev/null | grep -q '^loguser sacr 775$'"; then SCORE=$((SCORE+1)); log "✔ /mnt/logs sesuai"; else log "✘ Permission /mnt/logs salah"; fi
if check_remote $M2 "stat -c '%U %G %a' /mnt/archive 2>/dev/null | grep -q '^root root 755$'"; then SCORE=$((SCORE+1)); log "✔ /mnt/archive sesuai"; else log "✘ Permission /mnt/archive salah"; fi


log "==================== CEK FSTAB ===================="

if check_remote $M2 "grep -Ev '^#|^$' /etc/fstab | grep -Eq '(/dev/vdb1|UUID=.*)[[:space:]]+/mnt/app_data[[:space:]]+ext4'"; then SCORE=$((SCORE+1)); log "✔ Entri app_data benar"; else log "✘ Entri app_data salah"; fi
if check_remote $M2 "grep -Ev '^#|^$' /etc/fstab | grep -Eq '(/dev/vdb2|UUID=.*)[[:space:]]+/mnt/backup[[:space:]]+ext4'"; then SCORE=$((SCORE+1)); log "✔ Entri backup benar"; else log "✘ Entri backup salah"; fi
if check_remote $M2 "grep -Ev '^#|^$' /etc/fstab | grep -Eq '(vg_sacr/lv_logs|/dev/mapper/vg_sacr-lv_logs)[[:space:]]+/mnt/logs[[:space:]]+ext4'"; then SCORE=$((SCORE+1)); log "✔ Entri logs benar"; else log "✘ Entri logs salah"; fi
if check_remote $M2 "grep -Ev '^#|^$' /etc/fstab | grep -Eq '(vg_sacr/lv_archive|/dev/mapper/vg_sacr-lv_archive)[[:space:]]+/mnt/archive[[:space:]]+ext4'"; then SCORE=$((SCORE+1)); log "✔ Entri archive benar"; else log "✘ Entri archive salah"; fi

# ==========================================================
# ANSIBLE
# ==========================================================

log "==================== ANSIBLE ===================="

if check_remote $M1 "grep -q \"$M1\" /home/sacr/ansible/inventory" \
&& check_remote $M1 "grep -q \"$M2\" /home/sacr/ansible/inventory"
then
    SCORE=$((SCORE+3))
    log "✔ Inventory sesuai"
else
    log "✘ Inventory tidak sesuai"
fi

if check_remote $M1 "ansible all -i /home/sacr/ansible/inventory -m ping 2>/dev/null | grep -q SUCCESS"
then
    SCORE=$((SCORE+3))
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

if check_remote $M1 "grep -qE '^[[:space:]]*become:[[:space:]]*true' /home/sacr/ansible/default.yml 2>/dev/null"
then
    SCORE=$((SCORE+2))
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
localhost:/usr/bin# cat percobaansacr-exam.sh 
#!/bin/bash

# ==========================================================
# KONFIGURASI
# ==========================================================

GSHEET_WEB_APP_URL="-"

BOT_TOKEN=8990919507:AAFonVLoiBdTo6wT3uGW33Z8hYqoGQ_bIVw
CHAT_ID=8377686974

PESERTA=$1

if [ -z "$PESERTA" ]; then
    echo "ERROR: Data peserta tidak ditemukan. Jalankan 'sacr start' terlebih dahulu."
    exit 1
fi

DISK="/dev/vdb"

SCORE=0
MAX_SCORE=100

M1="machine1.sacr.id"
M2="machine2.sacr.id"

USER="sacr"
PASS="sacr2026"

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
log "=== SACR sacr REPORT ==="
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
    SCORE=$((SCORE+3))
    log "✔ SSH non-root login OK"
else
    log "✘ SSH belum diset non-root"
fi

# ==========================================================
# LINUX FUNDAMENTAL
# ==========================================================

log "==================== LINUX FUNDAMENTAL ===================="

if check_remote $M1 "[ -d ~/ujian_sacr ] && [ -f ~/ujian_sacr/audit.sh ] && [ -s ~/ujian_sacr/audit.sh ]"; then SCORE=$((SCORE+1)); log "✔ Soal 1 benar"; else log "✘ Soal 1 salah"; fi
if check_remote $M1 "[ \"\$(stat -c '%a' ~/ujian_sacr/audit.sh)\" = '740' ]"; then SCORE=$((SCORE+1)); log "✔ Soal 2 benar"; else log "✘ Soal 2 salah"; fi
if check_remote $M1 "getent group cyber >/dev/null && id analyst 2>/dev/null | grep -qw cyber"; then SCORE=$((SCORE+1)); log "✔ Soal 3 benar"; else log "✘ Soal 3 salah"; fi
if check_remote $M1 "[ -d ~/projek_linux ] && [ -f ~/projek_linux/readme.txt ] && [ -f ~/projek_linux/config.txt ] && [ -f ~/projek_linux/readme_backup.txt ] && cmp -s ~/projek_linux/readme.txt ~/projek_linux/readme_backup.txt"; then SCORE=$((SCORE+1)); log "✔ Soal 4 benar"; else log "✘ Soal 4 salah"; fi
if check_remote $M1 "[ -f ~/arsip/laporan_final.txt ] && [ ! -f ~/laporan.txt ]"; then SCORE=$((SCORE+1)); log "✔ Soal 5 benar"; else log "✘ Soal 5 salah"; fi
if check_remote $M1 "getent group tim_it >/dev/null && id operator01 2>/dev/null | grep -qw tim_it"; then SCORE=$((SCORE+1)); log "✔ Soal 6 benar"; else log "✘ Soal 6 salah"; fi

# ==========================================================
# SERVER FUNDAMENTAL
# ==========================================================

log "==================== SERVER FUNDAMENTAL ===================="

# Soal 1
if check_remote $M1 "[ -f ~/.ssh/ujian_key ] && [ -f ~/.ssh/ujian_key.pub ] && ssh-keygen -lf ~/.ssh/ujian_key.pub >/dev/null 2>&1"; then SCORE=$((SCORE+1)); log "✔ SSH key valid"; else log "✘ SSH key belum valid"; fi

# Soal 2
if check_remote $M1 "systemctl is-active --quiet mariadb"; then SCORE=$((SCORE+1)); log "✔ MariaDB aktif"; else log "✘ MariaDB tidak aktif"; fi

output=$(check_remote $M1 "echo $PASS | sudo -S mariadb -e \"SHOW GRANTS FOR 'user_ujian'@'localhost';\"")

if echo "$output" | grep -q SELECT; then
    SCORE=$((SCORE+1))
    log "✔ User MariaDB sesuai"
else
    log "✘ User MariaDB belum sesuai"
fi

# Soal 3
if check_remote $M1 "systemctl is-active --quiet nginx"; then SCORE=$((SCORE+1)); log "✔ Nginx aktif"; else log "✘ Nginx tidak aktif"; fi
if check_remote $M1 "echo $PASS | sudo -S nginx -T 2>/dev/null | grep -q 'listen 8080'"; then SCORE=$((SCORE+1)); log "✔ Nginx listen 8080"; else log "✘ Konfigurasi Nginx salah"; fi
if check_remote $M1 "curl -s http://localhost:8080 >/dev/null"; then SCORE=$((SCORE+1)); log "✔ Website dapat diakses"; else log "✘ Website tidak dapat diakses"; fi

# Soal 4
if check_remote $M1 "echo $PASS | sudo -S ufw status | grep -q 'Status: active'"; then SCORE=$((SCORE+1)); log "✔ UFW aktif"; else log "✘ UFW belum aktif"; fi
if check_remote $M1 "echo $PASS | sudo -S ufw status | grep -Eq '22/tcp.*ALLOW'"; then SCORE=$((SCORE+1)); log "✔ Rule SSH sesuai"; else log "✘ Rule SSH tidak sesuai"; fi
if check_remote $M1 "echo $PASS | sudo -S ufw status | grep -Eq '8080(/tcp)?[[:space:]]+ALLOW.*127\.0\.0\.1'"; then SCORE=$((SCORE+1)); log "✔ Rule localhost:8080 sesuai"; else log "✘ Rule localhost:8080 tidak sesuai"; fi
if check_remote $M1 "echo $PASS | sudo -S ufw status | grep -Eq '3306(/tcp)?.*DENY'"; then SCORE=$((SCORE+1)); log "✔ Rule MariaDB sesuai"; else log "✘ Rule MariaDB tidak sesuai"; fi

# ==========================================================
# DOCKER
# ==========================================================

log "==================== DOCKER ===================="

if check_remote $M2 "grep -q '^FROM' Dockerfile"; then SCORE=$((SCORE+1)); log "✔ Dockerfile valid"; else log "✘ Dockerfile tidak valid"; fi
if check_remote $M2 "grep -q 'Hello From Docker Container' app.py"; then SCORE=$((SCORE+1)); log "✔ app.py sesuai"; else log "✘ app.py tidak sesuai"; fi
if check_remote $M2 "docker image inspect python-demo >/dev/null 2>&1"; then SCORE=$((SCORE+2)); log "✔ Image python-demo ditemukan"; else log "✘ Image python-demo tidak ditemukan"; fi
if check_remote $M2 "docker run --rm python-demo 2>/dev/null | grep -q 'Hello From Docker Container'"; then SCORE=$((SCORE+3)); log "✔ Output container benar"; else log "✘ Output container salah"; fi
if check_remote $M2 "docker ps --format '{{.Names}}' | grep -q '^sacr-nginx$'"; then SCORE=$((SCORE+2)); log "✔ Container nginx berjalan"; else log "✘ Container nginx tidak berjalan"; fi
if check_remote $M2 "curl -s http://localhost:8080 | grep -qi nginx"; then SCORE=$((SCORE+3)); log "✔ Nginx container dapat diakses"; else log "✘ Nginx container tidak dapat diakses"; fi

# ==========================================================
# PUBLIC KEY INFRASTRUCTURE
# ==========================================================

log "==================== PUBLIC KEY INFRASTRUCTURE ===================="

# ================= ROOT CA =================
if check_remote $M1 "openssl x509 -in rootCA.crt -noout -subject 2>/dev/null | grep -Eq 'CN ?= ?SACR Root CA|SACR Root CA'"; then SCORE=$((SCORE+1)); log "✔ Subject Root CA benar"; else log "✘ Subject Root CA salah"; fi
if check_remote $M1 "openssl x509 -in rootCA.crt -noout -issuer 2>/dev/null | grep -Eq 'CN ?= ?SACR Root CA|SACR Root CA'"; then SCORE=$((SCORE+1)); log "✔ Issuer Root CA benar"; else log "✘ Issuer Root CA salah"; fi
if check_remote $M1 "openssl x509 -in rootCA.crt -text -noout 2>/dev/null | grep -q 'CA:TRUE'"; then SCORE=$((SCORE+1)); log '✔ Root CA memiliki CA:TRUE'; else log '✘ Root CA bukan Certificate Authority'; fi

# ================= INTERMEDIATE CA =================

if check_remote $M1 "openssl x509 -in intermediateCA.crt -noout -subject 2>/dev/null | grep -Eq 'CN ?= ?SACR Intermediate CA|SACR Intermediate CA'"; then SCORE=$((SCORE+1)); log "✔ Subject Intermediate CA benar"; else log "✘ Subject Intermediate CA salah"; fi
if check_remote $M1 "openssl x509 -in intermediateCA.crt -noout -issuer 2>/dev/null | grep -Eq 'CN ?= ?SACR Root CA|SACR Root CA'"; then SCORE=$((SCORE+1)); log "✔ Issuer Intermediate CA benar"; else log "✘ Issuer Intermediate CA salah"; fi
if check_remote $M1 "openssl verify -CAfile rootCA.crt intermediateCA.crt 2>/dev/null | grep -q ': OK'"; then SCORE=$((SCORE+2)); log "✔ Intermediate CA ditandatangani Root CA"; else log "✘ Intermediate CA tidak valid"; fi

# ================= SERVER CERTIFICATE =================

if check_remote $M1 "openssl x509 -in server.crt -noout -subject 2>/dev/null | grep -Eq 'CN ?= ?server.sacr.local|server.sacr.local'"; then SCORE=$((SCORE+1)); log "✔ Subject Server benar"; else log "✘ Subject Server salah"; fi
if check_remote $M1 "openssl x509 -in server.crt -noout -issuer 2>/dev/null | grep -Eq 'CN ?= ?SACR Intermediate CA|SACR Intermediate CA'"; then SCORE=$((SCORE+1)); log "✔ Issuer Server benar"; else log "✘ Issuer Server salah"; fi

# ================= FULL CHAIN =================
if check_remote $M1 "grep -c 'BEGIN CERTIFICATE' fullchain.pem 2>/dev/null | grep -q '^3$'"; then SCORE=$((SCORE+2)); log "✔ fullchain.pem berisi 3 sertifikat"; else log "✘ fullchain.pem tidak lengkap"; fi
if check_remote $M1 "openssl verify -CAfile rootCA.crt -untrusted intermediateCA.crt server.crt 2>/dev/null | grep -q ': OK'"; then SCORE=$((SCORE+4)); log "✔ Chain of Trust valid"; else log "✘ Chain of Trust gagal"; fi


# ==========================================================
# PARTISI & FILESYSTEM
# ==========================================================

log "==================== PARTISI & FILESYSTEM ===================="

if check_remote $M2 "lsblk ${DISK}1 >/dev/null 2>&1"; then SCORE=$((SCORE+1)); log "✔ Partisi ${DISK}1 ditemukan"; else log "✘ Partisi ${DISK}1 tidak ditemukan"; fi
if check_remote $M2 "lsblk ${DISK}2 >/dev/null 2>&1"; then SCORE=$((SCORE+1)); log "✔ Partisi ${DISK}2 ditemukan"; else log "✘ Partisi ${DISK}2 tidak ditemukan"; fi
if check_remote $M2 "lsblk ${DISK}3 >/dev/null 2>&1"; then SCORE=$((SCORE+1)); log "✔ Partisi ${DISK}3 ditemukan"; else log "✘ Partisi ${DISK}3 tidak ditemukan"; fi
if check_remote $M2 "lsblk -b -o SIZE ${DISK}1 | tail -1 | awk '{if(\$1>=190000000 && \$1<=210000000) exit 0; else exit 1}'"; then SCORE=$((SCORE+1)); log "✔ Ukuran ${DISK}1 sesuai (~200MB)"; else log "✘ Ukuran ${DISK}1 tidak sesuai"; fi
if check_remote $M2 "lsblk -b -o SIZE ${DISK}2 | tail -1 | awk '{if(\$1>=290000000 && \$1<=310000000) exit 0; else exit 1}'"; then SCORE=$((SCORE+1)); log "✔ Ukuran ${DISK}2 sesuai (~300MB)"; else log "✘ Ukuran ${DISK}2 tidak sesuai"; fi
if check_remote $M2 "echo $PASS | sudo -S blkid ${DISK}1 | grep -q 'TYPE=\"ext4\"'"; then SCORE=$((SCORE+1)); log "✔ ${DISK}1 ext4"; else log "✘ ${DISK}1 bukan ext4"; fi
if check_remote $M2 "echo $PASS | sudo -S blkid ${DISK}2 | grep -q 'TYPE=\"ext4\"'"; then SCORE=$((SCORE+1)); log "✔ ${DISK}2 ext4"; else log "✘ ${DISK}2 bukan ext4"; fi


log "==================== LVM ===================="

if check_remote $M2 "echo $PASS | sudo -S pvs --noheadings -o pv_name,vg_name | grep -q '${DISK}3.*vg_sacr'"; then SCORE=$((SCORE+1)); log "✔ PV ${DISK}3 tergabung ke vg_sacr"; else log "✘ PV vg_sacr tidak sesuai"; fi
if check_remote $M2 "echo $PASS | sudo -S vgs | grep -q '^ *vg_sacr'"; then SCORE=$((SCORE+1)); log "✔ VG vg_sacr ditemukan"; else log "✘ VG vg_sacr tidak ditemukan"; fi
if check_remote $M2 "echo $PASS | sudo -S lvs | grep -q 'lv_logs'"; then SCORE=$((SCORE+1)); log "✔ LV lv_logs ditemukan"; else log "✘ LV lv_logs tidak ditemukan"; fi
if check_remote $M2 "echo $PASS | sudo -S lvs | grep -q 'lv_archive'"; then SCORE=$((SCORE+1)); log "✔ LV lv_archive ditemukan"; else log "✘ LV lv_archive tidak ditemukan"; fi
if check_remote $M2 "echo $PASS | sudo -S lvs --units m --noheadings -o lv_name,lv_size | grep -E 'lv_logs.*200'"; then SCORE=$((SCORE+1)); log "✔ Ukuran lv_logs sesuai (200MB)"; else log "✘ Ukuran lv_logs tidak sesuai"; fi
if check_remote $M2 "echo $PASS | sudo -S blkid /dev/vg_sacr/lv_logs 2>/dev/null | grep -q 'TYPE=\"ext4\"'"; then SCORE=$((SCORE+1)); log "✔ lv_logs menggunakan ext4"; else log "✘ lv_logs belum diformat ext4"; fi
if check_remote $M2 "echo $PASS | sudo -S blkid /dev/vg_sacr/lv_archive 2>/dev/null | grep -q 'TYPE=\"ext4\"'"; then SCORE=$((SCORE+1)); log "✔ lv_archive menggunakan ext4"; else log "✘ lv_archive belum diformat ext4"; fi


log "==================== CEK MOUNT POINT ===================="

if check_remote $M2 "findmnt -n -o SOURCE /mnt/app_data | grep -q '${DISK}1'"; then SCORE=$((SCORE+1)); log "✔ /mnt/app_data mount dari ${DISK}1"; else log "✘ Mount /mnt/app_data salah"; fi
if check_remote $M2 "findmnt -n -o SOURCE /mnt/backup | grep -q '${DISK}2'"; then SCORE=$((SCORE+1)); log "✔ /mnt/backup mount dari ${DISK}2"; else log "✘ Mount /mnt/backup salah"; fi
if check_remote $M2 "findmnt -n -o SOURCE /mnt/logs | grep -q 'vg_sacr-lv_logs'"; then SCORE=$((SCORE+1)); log "✔ /mnt/logs mount dari lv_logs"; else log "✘ Mount /mnt/logs salah"; fi
if check_remote $M2 "findmnt -n -o SOURCE /mnt/archive | grep -q 'vg_sacr-lv_archive'"; then SCORE=$((SCORE+1)); log "✔ /mnt/archive mount dari lv_archive"; else log "✘ Mount /mnt/archive salah"; fi


log "==================== CEK FILE UJI ===================="

if check_remote $M2 "grep -qx 'server=production' /mnt/app_data/app.conf 2>/dev/null"; then SCORE=$((SCORE+1)); log "✔ app.conf sesuai"; else log "✘ Isi app.conf tidak sesuai"; fi
if check_remote $M2 "[ -f /mnt/backup/backup.tar ]"; then SCORE=$((SCORE+1)); log "✔ backup.tar ditemukan"; else log "✘ backup.tar tidak ditemukan"; fi
if check_remote $M2 "[ -f /mnt/logs/access.log ] && [ -f /mnt/logs/error.log ]"; then SCORE=$((SCORE+1)); log "✔ File log lengkap"; else log "✘ File log tidak lengkap"; fi


log "==================== CEK OWNER & PERMISSION ===================="

if check_remote $M2 "stat -c '%U %G %a' /mnt/app_data 2>/dev/null | grep -q '^root root 755$'"; then SCORE=$((SCORE+1)); log "✔ /mnt/app_data sesuai"; else log "✘ Permission /mnt/app_data salah"; fi
if check_remote $M2 "stat -c '%U %G %a' /mnt/backup 2>/dev/null | grep -q '^backupuser sacr 770$'"; then SCORE=$((SCORE+1)); log "✔ /mnt/backup sesuai"; else log "✘ Permission /mnt/backup salah"; fi
if check_remote $M2 "stat -c '%U %G %a' /mnt/logs 2>/dev/null | grep -q '^loguser sacr 775$'"; then SCORE=$((SCORE+1)); log "✔ /mnt/logs sesuai"; else log "✘ Permission /mnt/logs salah"; fi
if check_remote $M2 "stat -c '%U %G %a' /mnt/archive 2>/dev/null | grep -q '^root root 755$'"; then SCORE=$((SCORE+1)); log "✔ /mnt/archive sesuai"; else log "✘ Permission /mnt/archive salah"; fi


log "==================== CEK FSTAB ===================="

if check_remote $M2 "grep -Ev '^#|^$' /etc/fstab | grep -Eq '(/dev/vdb1|UUID=.*)[[:space:]]+/mnt/app_data[[:space:]]+ext4'"; then SCORE=$((SCORE+1)); log "✔ Entri app_data benar"; else log "✘ Entri app_data salah"; fi
if check_remote $M2 "grep -Ev '^#|^$' /etc/fstab | grep -Eq '(/dev/vdb2|UUID=.*)[[:space:]]+/mnt/backup[[:space:]]+ext4'"; then SCORE=$((SCORE+1)); log "✔ Entri backup benar"; else log "✘ Entri backup salah"; fi
if check_remote $M2 "grep -Ev '^#|^$' /etc/fstab | grep -Eq '(vg_sacr/lv_logs|/dev/mapper/vg_sacr-lv_logs)[[:space:]]+/mnt/logs[[:space:]]+ext4'"; then SCORE=$((SCORE+1)); log "✔ Entri logs benar"; else log "✘ Entri logs salah"; fi
if check_remote $M2 "grep -Ev '^#|^$' /etc/fstab | grep -Eq '(vg_sacr/lv_archive|/dev/mapper/vg_sacr-lv_archive)[[:space:]]+/mnt/archive[[:space:]]+ext4'"; then SCORE=$((SCORE+1)); log "✔ Entri archive benar"; else log "✘ Entri archive salah"; fi

# ==========================================================
# ANSIBLE
# ==========================================================

log "==================== ANSIBLE ===================="

if check_remote $M1 "grep -q \"$M1\" /home/sacr/ansible/inventory" \
&& check_remote $M1 "grep -q \"$M2\" /home/sacr/ansible/inventory"
then
    SCORE=$((SCORE+3))
    log "✔ Inventory sesuai"
else
    log "✘ Inventory tidak sesuai"
fi

if check_remote $M1 "ansible all -i /home/sacr/ansible/inventory -m ping 2>/dev/null | grep -q SUCCESS"
then
    SCORE=$((SCORE+3))
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

if check_remote $M1 "grep -qE '^[[:space:]]*become:[[:space:]]*true' /home/sacr/ansible/default.yml 2>/dev/null"
then
    SCORE=$((SCORE+2))
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
