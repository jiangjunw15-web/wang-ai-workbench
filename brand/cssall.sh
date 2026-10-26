#!/bin/bash
docker exec autogpt bash -c '
echo "=== css files present ==="
find /app/frontend/.next/static/css -type f | head -12
echo "=== which have --sidebar-background ==="
for F in $(find /app/frontend/.next/static/css -type f); do
  if grep -q -- "--sidebar-background" "$F" 2>/dev/null; then
    echo "HIT: $F"
    grep -o -- "--sidebar-background:[^;]*" "$F" | head -2
    grep -o -- "--primary:[^;]*" "$F" | head -2
  fi
done
'
