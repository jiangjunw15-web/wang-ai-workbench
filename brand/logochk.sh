#!/bin/bash
docker exec autogpt bash -c '
echo "=== references in chunks ==="
grep -rhoE "wang-logo-(light|dark)\.png|autogpt-logo-(light|dark)-bg\.png" /app/frontend/.next/static/chunks --include=*.js 2>/dev/null | sort | uniq -c
echo "=== public dir ==="
ls -la /app/frontend/public/wang-logo-*.png 2>/dev/null
echo "=== what the server actually serves ==="
curl -s -o /tmp/x.png -w "wang-logo-light.png: %{http_code} %{size_download}B\n" http://127.0.0.1:3000/wang-logo-light.png
curl -s -o /tmp/y.png -w "autogpt-logo-light-bg.png: %{http_code} %{size_download}B\n" http://127.0.0.1:3000/autogpt-logo-light-bg.png
'
