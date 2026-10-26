#!/bin/bash
set -euo pipefail
docker cp /mnt/d/automate/brand/logo_rename.py autogpt:/tmp/logo_rename.py
docker exec autogpt python /tmp/logo_rename.py
docker exec autogpt supervisorctl -c /opt/autogpt/single-container/supervisor/supervisord.conf restart runtime:next 2>&1 | tail -1
echo "--- verify ---"
docker exec autogpt ls -la /app/frontend/public/wang-logo-light.png /app/frontend/public/wang-logo-dark.png
docker exec autogpt bash -c 'grep -rhoE "wang-logo-(light|dark)\.png" /app/frontend/.next/static/chunks --include=*.js 2>/dev/null | sort | uniq -c'
curl -s -o /dev/null -w "served wang-logo-light.png: %{http_code}\n" http://127.0.0.1:3000/wang-logo-light.png
