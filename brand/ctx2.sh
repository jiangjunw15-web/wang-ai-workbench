#!/bin/bash
docker exec autogpt bash -c '
echo "=== context around href:/artifacts ==="
grep -rhoE ".{140}href:\"/artifacts\".{60}" /app/frontend/.next/static/chunks --include=*.js 2>/dev/null | head -3
echo
echo "=== context around href:/marketplace (sidebar area) ==="
grep -rhoE ".{200}href:\"/marketplace\".{40}" /app/frontend/.next/static/chunks --include=*.js 2>/dev/null | head -2
'
