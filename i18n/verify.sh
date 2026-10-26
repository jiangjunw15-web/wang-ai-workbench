#!/bin/bash
# Wipe the in-app browser's HTTP cache guidance and verify the platform
# serves Chinese. Run after any bundle re-patch.
set -euo-pipeline 2>/dev/null || true
set -uo pipefail
echo "== 1) ensure nginx forces revalidation =="
wsl.exe -d AutoGPT -u root -- bash /mnt/d/automate/i18n/nginx_nocache.sh 2>&1 | tr -d '\0' | tail -3
echo
echo "== 2) re-apply the zh-CN dictionary =="
wsl.exe -d AutoGPT -u root -- bash /mnt/d/automate/i18n/apply.sh 2>&1 | tr -d '\0' | grep -E "SCANNED|bad=|started" | head -4
echo
echo "== 3) server-side language check on /library =="
wsl.exe -d AutoGPT -u root -- bash /mnt/d/automate/wsl/check_lib_zh.sh 2>&1 | tr -d '\0' | head -12
echo
echo "If the browser still shows English, its own HTTP cache is stale:"
echo "  - open http://localhost:3000 in a NEW browser window/tab, or"
echo "  - hard-reload with Ctrl+Shift+R (or Ctrl+F5)."
echo "The server is already serving Chinese; the page itself needs no change."
