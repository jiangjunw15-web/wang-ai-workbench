#!/bin/bash
# Headless screenshots of the platform (container chromium), then export.
set -euo pipefail
docker exec autogpt bash -c '
for spec in "library|http://127.0.0.1:3000/library" "ai-order|http://127.0.0.1:3000/wang/ai-order" "magpie|http://127.0.0.1:3000/wang/magpie"; do
  name="${spec%%|*}"; url="${spec##*|}"
  rm -rf /tmp/prof-$name; rm -f "/tmp/$name.png"
  chromium --headless --no-sandbox --disable-gpu --hide-scrollbars \
    --user-data-dir="/tmp/prof-$name" --disable-application-cache --disk-cache-size=1 \
    --window-size=1440,900 --virtual-time-budget=12000 \
    --screenshot="/tmp/$name.png" "$url" >/dev/null 2>&1
  [ -f "/tmp/$name.png" ] && echo "shot $name" || echo "FAILED $name"
done
'
mkdir -p /d/automate/out
for N in library ai-order magpie; do
  docker cp "autogpt:/tmp/$N.png" "/d/automate/out/wang-$N.png" 2>/dev/null && echo "exported $N" || echo "skip $N"
done
ls -la /d/automate/out/*.png 2>/dev/null | head -5
