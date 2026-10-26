#!/bin/bash
docker exec autogpt bash -c '
echo "=== where does the brown come from? ==="
grep -rhoE "background(-color)?:[^;}]*132[ ,][^;}]*|background(-color)?:[^;}]*rgb\(1?3?2?,? ?9?5?,? ?8?2?\)" /app/frontend/.next/static/css/*.css 2>/dev/null | head -5
echo "=== hardcoded brown-ish hexes in css ==="
grep -rhoE "#[0-9a-fA-F]{6}" /app/frontend/.next/static/css/*.css 2>/dev/null | sort | uniq -c | sort -rn | head -12
echo "=== sidebar-related hardcoded colors ==="
grep -rhoE "sidebar[a-z-]*:[^;}]{0,40}" /app/frontend/.next/static/css/*.css 2>/dev/null | head -12
'
