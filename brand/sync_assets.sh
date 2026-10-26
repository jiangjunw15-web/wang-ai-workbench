#!/bin/bash
# Sync the branded public assets from the running container into the
# persistent volume, so they survive container recreation.
set -euo pipefail
docker cp autogpt:/app/frontend/public/autogpt-logo-light-bg.png /tmp/l1.png
docker cp autogpt:/app/frontend/public/autogpt-logo-dark-bg.png /tmp/l2.png
docker cp autogpt:/app/frontend/public/favicon.ico /tmp/f.ico
docker cp autogpt:/app/frontend/public/favicon-local.ico /tmp/fl.ico
docker cp autogpt:/app/frontend/public/apple-touch-icon.png /tmp/at.png
docker run --rm -v wang-frontend:/t -v /tmp:/s alpine sh -c '
cp /s/l1.png /t/public/autogpt-logo-light-bg.png
cp /s/l2.png /t/public/autogpt-logo-dark-bg.png
cp /s/f.ico  /t/public/favicon.ico
cp /s/fl.ico /t/public/favicon-local.ico
cp /s/at.png /t/public/apple-touch-icon.png
echo SYNCED'
rm -f /tmp/l1.png /tmp/l2.png /tmp/f.ico /tmp/fl.ico /tmp/at.png
