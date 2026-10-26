#!/bin/bash
docker exec autogpt bash -c '
echo "=== backups count ==="
ls /root/zh_backup | wc -l
echo "=== does any backup contain the AutoGPT logo component? ==="
grep -l "AutoGPT Logo" /root/zh_backup/* 2>/dev/null | wc -l
echo "=== current chunks with the component ==="
grep -rl "AutoGPT Logo" /app/frontend/.next/static/chunks --include=*.js 2>/dev/null | wc -l
echo "=== sample backup names ==="
ls /root/zh_backup | head -6
'
