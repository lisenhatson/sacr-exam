#!/bin/bash

TIME_LOG="/tmp/sacr_start_time.log"

if [ ! -f "$TIME_LOG" ]; then
    echo "Belum ada sesi ujian."
    echo "Jalankan:"
    echo "sacr start"
    exit 1
fi

echo ""
read -p "Masukkan nama peserta : " PESERTA

echo ""
echo "Menghitung nilai..."
echo ""

sacr-exam "$PESERTA"
