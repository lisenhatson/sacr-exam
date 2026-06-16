#!/bin/bash

# === PENGATURAN GOOGLE SHEET ===
# PASTIKAN ANDA MENGGUNAKAN URL BARU DARI DEPLOYMENT TERBARU
GSHEET_WEB_APP_URL="-"

# === PENGATURAN TELEGRAM ===
BOT_TOKEN="-"
CHAT_ID="-"

# === INPUT PESERTA ===
read -p "Masukkan nama peserta: " PESERTA

# === KONFIGURASI ===
score=0
M1="machine1.sacr.id"
M2="machine2.sacr.id"
USER="sysadmin"
PASS="sysadmin"
REPORT="/tmp/sacr_report_${PESERTA// /_}.txt"
TIME_LOG="/tmp/sacr_start_time.log"
touch $REPORT

# === HITUNG WAKTU PENGERJAAN ===
if [ -f "$TIME_LOG" ]; then
    START_TIME=$(cat "$TIME_LOG")
    END_TIME=$(date +%s)
    TOTAL_SECONDS=$((END_TIME - START_TIME))
    MINUTES=$((TOTAL_SECONDS / 60))
    SECONDS=$((TOTAL_SECONDS % 60))
    WAKTU_PENGERJAAN="${MINUTES} menit ${SECONDS} detik"
    rm "$TIME_LOG"
else
    WAKTU_PENGERJAAN="Tidak tercatat"
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
if check_remote $M1 "hostnamectl 2>/dev/null | grep -q 'machine1.sacr.id'" && check_remote $M2 "hostnamectl 2>/dev/null | grep -q 'machine2.sacr.id'"; then score=$((score+3)); log "✔ Hostname sesuai"; else log "✘ Hostname salah"; fi
if check_remote $M1 "grep -q '^PermitRootLogin no' /etc/ssh/sshd_config 2>/dev/null" && check_remote $M2 "grep -q '^PermitRootLogin no' /etc/ssh/sshd_config 2>/dev/null"; then score=$((score+3)); log "✔ SSH non-root login OK"; else log "✘ SSH belum diset non-root"; fi

log "==================== USER & GROUP ===================="
if check_remote $M1 "getent group sacr &>/dev/null && getent group pclabs &>/dev/null"; then score=$((score+2)); log "✔ Grup sacr & pclabs ada"; else log "✘ Grup belum lengkap"; fi
if check_remote $M1 "id adit &>/dev/null && id sopo &>/dev/null && id backupuser &>/dev/null && id jarwo &>/dev/null && id denis &>/dev/null"; then score=$((score+2)); log "✔ Semua user ada"; else log "✘ User belum lengkap"; fi
if check_remote $M1 "id adit 2>/dev/null | grep -q sacr && id adit 2>/dev/null | grep -q pclabs"; then score=$((score+2)); log "✔ adit grup benar"; else log "✘ adit belum tergabung benar"; fi
if check_remote $M1 "id sopo 2>/dev/null | grep sacr && id jarwo 2>/dev/null | grep sacr && id backupuser 2>/dev/null | grep sacr"; then score=$((score+2)); log "✔ sopo, jarwo, backupuser di sacr"; else log "✘ Grup anggota salah"; fi
if check_remote $M1 "[ \"\$(id -u denis 2>/dev/null)\" = 2025 ] && grep -q '^denis:.*:/sbin/nologin$' /etc/passwd 2>/dev/null"; then score=$((score+2)); log "✔ Denis UID & shell OK"; else log "✘ Denis belum sesuai"; fi
if check_remote $M1 "for u in adit sopo backupuser jarwo; do sshpass -p sysadmin ssh -q -o StrictHostKeyChecking=no -o ConnectTimeout=5 \$u@$M1 exit 2>/dev/null || exit 1; done"; then score=$((score+2)); log '✔ Password benar untuk semua user'; else log '✘ Password belum benar untuk salah satu user'; fi

UID1=$(check_remote $M1 "id -u backupuser" | tr -d '\r\n')
UID2=$(check_remote $M2 "id -u backupuser" | tr -d '\r\n')
GID1=$(check_remote $M1 "getent group sacr | cut -d: -f3" | tr -d '\r\n')
GID2=$(check_remote $M2 "getent group sacr | cut -d: -f3" | tr -d '\r\n')
if [ "$UID1" = "$UID2" ] && [ "$GID1" = "$GID2" ] && [ -n "$UID1" ]; then log "✔ backupuser dan grup sacr sinkron di kedua mesin (UID=$UID1, GID=$GID1)"; else log "✘ UID/GID backupuser atau sacr berbeda (UID: $UID1/$UID2, GID: $GID1/$GID2)"; fi

log "==================== FILE PERMISSION ===================="
if check_remote $M1 "[ -d /data/sacr ] && stat -c '%U %G' /data/sacr 2>/dev/null | grep -q 'adit sacr'"; then score=$((score+3)); log "✔ /data/sacr milik adit:sacr"; else log "✘ Kepemilikan salah"; fi
if check_remote $M1 '[ "$(stat -c "%a" /data/sacr 2>/dev/null)" -eq 760 ] || [ "$(stat -c "%a" /data/sacr 2>/dev/null)" -eq 1760 ]'; then score=$((score+3)); log "✔ Permission 760 OK"; else log "✘ Permission salah"; fi
if check_remote $M1 "stat -c '%A' /data/sacr 2>/dev/null | grep -qi 't'"; then score=$((score+3)); log "✔ Sticky bit OK"; else log "✘ Sticky bit belum"; fi
OWNER=$(check_remote $M1 "sudo stat -c '%U' /data/sacr/info.txt 2>/dev/null")
PERM=$(check_remote $M1 "sudo stat -c '%a' /data/sacr/info.txt 2>/dev/null")
if [ "$OWNER" = "jarwo" ] && [ "$PERM" = "400" ]; then score=$((score+2)); log "✔ info.txt hanya jarwo"; else log "✘ info.txt permission salah"; fi

log "==================== BASH SCRIPTING ===================="
if check_remote $M1 "[ -x /usr/local/bin/greetuser ] && grep -q 'read' /usr/local/bin/greetuser 2>/dev/null"; then score=$((score+5)); log "✔ greetuser OK"; else log "✘ greetuser salah"; fi
if check_remote $M1 "[ -x /home/sysadmin/welkem.sh ] && echo | /home/sysadmin/welkem.sh &>/dev/null"; then score=$((score+3)); log "✔ welkem.sh OK"; else log "✘ welkem.sh belum bisa dijalankan"; fi

log "==================== DOCKER WEB ===================="
if check_remote $M2 "docker image ls 2>/dev/null | grep -q 'sacr-web-image'"; then score=$((score+4)); log "✔ Image ada"; else log "✘ Image belum dibuat"; fi
if check_remote $M2 "docker ps --filter name=sacr-web-con --format '{{.Ports}}' 2>/dev/null | grep -q '8080->'"; then score=$((score+4)); log "✔ Container jalan dan port 8080 terbuka"; else log "✘ Container belum / port belum sesuai"; fi
if check_remote $M2 "curl -s localhost:8080 >/dev/null 2>&1"; then score=$((score+3)); log "✔ Website bisa dibuka"; else log "✘ Website gagal"; fi

log "==================== PARTISI MACHINE1 ===================="
if check_remote $M1 "mount 2>/dev/null | grep -q '/mnt/data_backup' && [ -d /mnt/data_backup/ssh_logs ]"; then score=$((score+4)); log "✔ Mount OK & ssh_logs ada"; else log "✘ Mount / ssh_logs gagal"; fi
if check_remote $M1 "stat -c '%U %G %a' /mnt/data_backup 2>/dev/null | grep -q 'backupuser sacr 665'"; then score=$((score+4)); log "✔ Permission OK"; else log "✘ Permission salah"; fi

log "==================== PARTISI MACHINE2 + LVM ===================="
if check_remote $M2 "lsblk 2>/dev/null | grep -q lvm"; then score=$((score+4)); log "✔ Partisi LVM ada"; else log "✘ LVM tidak ada"; fi
if check_remote $M2 "sudo vgs 2>/dev/null | grep sacr_data_storage && sudo vgs 2>/dev/null | grep sacr_log_storage"; then score=$((score+4)); log "✔ VG OK"; else log "✘ VG belum"; fi
if check_remote $M2 "mount 2>/dev/null | grep -q '/mnt/sacr_data_1' && mount 2>/dev/null | grep -q '/mnt/sacr_data_2'"; then score=$((score+6)); log "✔ Mount data_store OK"; else log "✘ Mount data_store gagal"; fi
if check_remote $M2 "mount 2>/dev/null | grep -q '/mnt/sacr_ssh_log'"; then score=$((score+3)); log "✔ ssh_log_store OK"; else log "✘ ssh_log_store belum"; fi
if check_remote $M2 "stat -c '%U %G %a' /mnt/sacr_ssh_log 2>/dev/null | grep -q 'backupuser sacr 665'"; then score=$((score+2)); log "✔ ssh_log_store permission OK"; else log "✘ ssh_log_store permission salah"; fi

log "==================== NFS + AUTOfS + CRON ===================="
if check_remote $M1 "sudo exportfs -v 2>/dev/null | grep -q '/mnt/data_backup'"; then score=$((score+3)); log "✔ NFS export OK"; else log "✘ NFS export belum"; fi
if check_remote $M2 "sudo showmount -e $M1 2>/dev/null | grep -q '/mnt/data_backup'"; then score=$((score+2)); log "✔ NFS terlihat dari machine2"; else log "✘ NFS tidak terlihat"; fi
if check_remote $M2 "sudo mount 2>/dev/null | grep -q '/mnt/backup' && sudo stat -c '%U %G' /mnt/backup 2>/dev/null | grep -q 'backupuser sacr'"; then score=$((score+4)); log "✔ AutoFS OK"; else log "✘ AutoFS gagal"; fi
if check_remote $M2 "crontab -l 2>/dev/null | grep -q '59 23.*cp.*auth.log.*mnt/backup'"; then score=$((score+2)); log '✔ Cron backup OK'; else log '✘ Cron backup belum ada'; fi
if check_remote $M2 "grep -q '/mnt/sacr_ssh_log' /etc/rsyslog.conf 2>/dev/null || grep -q '/mnt/sacr_ssh_log' /etc/ssh/sshd_config 2>/dev/null"; then score=$((score+3)); log "✔ SSH log diarahkan ke disk"; else log "✘ SSH log belum diarahkan"; fi

log "==================== ANSIBLE ===================="
if [ -f /home/sysadmin/ansible/inventory ] && grep -q "$M1" /home/sysadmin/ansible/inventory && grep -q "$M2" /home/sysadmin/ansible/inventory; then score=$((score+3)); log "✔ Inventory OK"; else log "✘ Inventory salah"; fi
if sshpass -p sysadmin ansible all -i /home/sysadmin/ansible/inventory -m ping --ask-pass 2>/dev/null | grep -q "SUCCESS"; then score=$((score+3)); log "✔ Ping berhasil"; else log "✘ Ping gagal"; fi
if check_remote $M1 "id managed 2>/dev/null && getent group cyberranger 2>/dev/null && id managed 2>/dev/null | grep cyberranger" && check_remote $M2 "id managed 2>/dev/null && getent group cyberranger 2>/dev/null"; then score=$((score+4)); log "✔ managed + cyberranger sesuai"; else log "✘ Ansible user/group salah"; fi
if grep -qE '^\s*become:\s*true' /home/sysadmin/ansible/default.yml 2>/dev/null; then score=$((score+1)); log "✔ Sudo prompt aktif"; else log "✘ Tidak ada sudo prompt"; fi

# ==========================================================

log ""
log "==================== HASIL AKHIR ===================="
log "Peserta: $PESERTA"
log "Skor akhir: $score / 100"
log "Waktu Pengerjaan: $WAKTU_PENGERJAAN"

if [ $score -ge 70 ]; then
    STATUS="🎉 STATUS: SYSADMIN FINISH — LULUS ✅"
else
    STATUS="❌ STATUS: BELUM LULUS"
fi
log "$STATUS"


# 1. Mengirim ke Google Sheet
curl -s -L -X POST "$GSHEET_WEB_APP_URL" \
-H "Content-Type: application/json" \
-d "{\"name\": \"$PESERTA\", \"score\": $score, \"time\": \"$WAKTU_PENGERJAAN\"}" >/dev/null 2>&1

# 2. Mengirim ke Telegram
curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="📄 *Hasil OSC SYSADMIN 2025*
👤 Peserta: $PESERTA
📊 Skor: $score / 100
⏱️ Waktu: $WAKTU_PENGERJAAN
📅 Tanggal: $(date +'%d-%m-%Y %H:%M:%S')
$STATUS" \
    -d parse_mode="Markdown" >/dev/null

log ""
log "=== SELESAI ==="
