#!/bin/bash
# Install CJK fonts in the container so headless screenshots render Chinese.
set -euo pipefail
docker exec autogpt bash -c '
if fc-list 2>/dev/null | grep -qi "noto.*cjk\|wqy\|droid.*fallback"; then
  echo "CJK_FONT_PRESENT"
  exit 0
fi
apt-get update -qq >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq fonts-noto-cjk fonts-wqy-zenhei >/dev/null 2>&1
fc-cache -f >/dev/null 2>&1 || true
fc-list 2>/dev/null | grep -ci "cjk\|wqy" || echo 0
'
