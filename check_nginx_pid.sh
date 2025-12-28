#!/bin/bash

echo "=== Mencari Process Nginx ==="

# 1. Cari Nginx yang dijalankan dari /usr/sbin/nginx (Standard Install)
SYSTEM_PID=$(ps aux | grep 'nginx: master process /usr/sbin/nginx' | grep -v grep | awk '{print $2}')

if [ -n "$SYSTEM_PID" ]; then
    echo "✅ DITEMUKAN: System Nginx (dari apt install)"
    echo "PID: $SYSTEM_PID"
    echo ""
    echo "Untuk mematikan (Kill):"
    echo "sudo kill $SYSTEM_PID"
else
    echo "❌ System Nginx (/usr/sbin/nginx) TIDAK ditemukan."
fi

echo ""
echo "=== Process Nginx Lainnya (Hati-hati, mungkin punya System/Proxy) ==="
ps aux | grep 'nginx: master' | grep -v '/usr/sbin/nginx' | grep -v grep | awk '{print "PID: " $2 " | User: " $1 " | Cmd: " $11 " " $12 " " $13 " " $14 " " $15}'
