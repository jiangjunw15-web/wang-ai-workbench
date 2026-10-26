#!/bin/bash
# Force browsers to revalidate /_next/static chunks so a patched bundle takes
# effect without manual cache clearing. Idempotent: safe to re-run.
set -euo pipefail
CONF=/opt/autogpt/single-container/nginx/nginx.conf
MARK="# zh-CN bundle revalidation (local setup)"
if docker exec autogpt grep -qF "$MARK" "$CONF"; then
  echo "ALREADY_PATCHED"
  exit 0
fi
docker exec autogpt python - "$CONF" "$MARK" <<'PYEOF'
import sys
conf, mark = sys.argv[1], sys.argv[2]
with open(conf, encoding="utf-8") as f:
    text = f.read()
anchor = "        location / {"
block = (
    "        # zh-CN bundle revalidation (local setup)\n"
    "        location /_next/static/ {\n"
    "            proxy_pass http://autogpt_frontend;\n"
    "            proxy_http_version 1.1;\n"
    "            proxy_set_header Host $autogpt_public_host;\n"
    "            proxy_hide_header Cache-Control;\n"
    "            add_header Cache-Control \"no-cache, must-revalidate\" always;\n"
    "        }\n\n"
)
if anchor not in text:
    raise SystemExit("location / anchor not found")
text = text.replace(anchor, block + anchor, 1)
with open(conf, "w", encoding="utf-8") as f:
    f.write(text)
print("NGINX_PATCHED")
PYEOF
docker exec autogpt nginx -t 2>&1 | tail -2
docker exec autogpt supervisorctl -c /opt/autogpt/single-container/supervisor/supervisord.conf restart runtime:nginx 2>&1 | tail -1
