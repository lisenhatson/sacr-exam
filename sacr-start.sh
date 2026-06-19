#!/bin/bash

NAME_FILE="/tmp/sacr_name.log"
TIME_FILE="/tmp/sacr_start_time.log"

clear

echo "======================================"
echo "      SACR SYSADMIN EXAM SYSTEM"
echo "======================================"
echo ""

read -p "Masukkan Nama Peserta : " PESERTA

echo "$PESERTA" > "$NAME_FILE"
date +%s > "$TIME_FILE"

rm -f /tmp/sacr_report_*

echo ""
echo "======================================"
echo "Peserta : $PESERTA"
echo "Mulai   : $(date)"
echo "======================================"
echo ""

echo "Ujian telah dimulai."
echo ""

echo "Gunakan perintah:"
echo ""
echo "    sacr finish"
echo ""
echo "untuk mengakhiri ujian."
echo ""
