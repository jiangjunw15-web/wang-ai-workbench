#!/bin/bash
docker exec autogpt bash -c '
echo "=== which css contains the :root tokens ==="
grep -l "\-\-primary" /app/frontend/.next/static/css/*.css 2>/dev/null | head -5
echo "=== current --primary value in them ==="
for F in $(grep -l "\-\-primary" /app/frontend/.next/static/css/*.css 2>/dev/null | head -3); do
  echo "--- $F ---"
  grep -o "\-\-primary:[^;]*;" "$F" | head -2
done
echo "=== is ice-blue present anywhere? ==="
grep -l "56 189 248" /app/frontend/.next/static/css/*.css 2>/dev/null | head -3 || echo "(ice-blue not found in css)"
echo "=== does any css contain the rgb-triplet form? ==="
grep -c "rgb" /app/frontend/.next/static/css/*.css 2>/dev/null | head -5
'
