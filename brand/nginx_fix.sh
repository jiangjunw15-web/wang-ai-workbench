#!/bin/bash
set -euo pipefail
CONF=/opt/autogpt/single-container/nginx/nginx.conf
docker cp /mnt/d/automate/brand/nginx_patch.py autogpt:/tmp/nginx_patch.py
docker exec autogpt python /tmp/nginx_patch.py
echo "--- rule count ---"
docker exec autogpt grep -c "wang-static-revalidate" "$CONF" || true
echo "--- nginx test ---"
docker exec autogpt nginx -t -c "$CONF" 2>&1 | tail -2
echo "--- reload ---"
docker exec autogpt supervisorctl -c /opt/autogpt/single-container/supervisor/supervisord.conf restart runtime:nginx 2>&1 | tail -1
sleep 3
echo "--- cache header probe ---"
docker exec autogpt curl -s -I "http://127.0.0.1:3000/_next/static/chunks/webpack-x.js" 2>/dev/null | grep -i "cache-control" || echo "(probe path may 404; header check needs a real file)"
