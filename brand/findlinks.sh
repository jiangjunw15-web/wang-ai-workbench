#!/bin/bash
docker exec autogpt bash -c '
echo "=== search for the sidebar link arrays in the bundle ==="
grep -rhoE "\{name:\"[A-Za-z ]+\",href:\"/[a-z]+\"" /app/frontend/.next/static/chunks --include=*.js 2>/dev/null | sort -u | head -20
echo "=== artifacts / marketplace hrefs ==="
grep -rhoE "href:\"/[a-z]+\"" /app/frontend/.next/static/chunks --include=*.js 2>/dev/null | sort | uniq -c | sort -rn | head -20
'
