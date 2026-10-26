#!/bin/bash
set -euo pipefail
docker cp /mnt/d/automate/wang/nginx_route.py autogpt:/tmp/nginx_route.py
docker exec autogpt python /tmp/nginx_route.py
docker exec autogpt nginx -t -c /opt/autogpt/single-container/nginx/nginx.conf 2>&1 | tail -1
docker exec autogpt supervisorctl -c /opt/autogpt/single-container/supervisor/supervisord.conf restart runtime:nginx 2>&1 | tail -1
sleep 3
echo "--- probe through the platform ---"
curl -s -m 10 -o /dev/null -w "ai-order: %{http_code}\n" http://localhost:3000/wang/ai-order
curl -s -m 10 -o /dev/null -w "magpie:   %{http_code}\n" http://localhost:3000/wang/magpie
