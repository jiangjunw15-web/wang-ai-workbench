#!/bin/bash
set -euo pipefail
docker cp /mnt/d/automate/brand/restore_backup.py autogpt:/tmp/restore_backup.py
docker exec autogpt python /tmp/restore_backup.py
docker exec autogpt supervisorctl -c /opt/autogpt/single-container/supervisor/supervisord.conf restart runtime:next 2>&1 | tail -1
echo "--- verify ---"
docker exec autogpt bash -c 'echo ARIA=\$(grep -rl "AutoGPT Logo" /app/frontend/.next/static/chunks --include=*.js 2>/dev/null | wc -l)'
