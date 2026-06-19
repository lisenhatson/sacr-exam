#!/bin/bash

NAME_FILE="/tmp/sacr_name.log"

if [ ! -f "$NAME_FILE" ]; then
    echo "Belum ada sesi ujian."
    echo "Jalankan:"
    echo "sacr start"
    exit 1
fi

PESERTA=$(cat "$NAME_FILE")

echo ""
echo "Menghitung nilai..."
echo ""

sacr-grade "$PESERTA"
