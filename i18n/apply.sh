#!/bin/bash
# Localize the frontend bundle, then syntax-check it, inside the container.
set -euo pipefail
echo "== applying zh-CN patch =="
docker cp /mnt/d/automate/i18n/patch_bundle.py autogpt:/tmp/patch_bundle.py
docker cp /mnt/d/automate/i18n/zh-cn.json autogpt:/tmp/zh-cn.json
docker exec autogpt python /tmp/patch_bundle.py /tmp/zh-cn.json

echo "== syntax check =="
docker exec -i autogpt node -e '
const fs = require("fs");
const path = require("path");
const dir = "/app/frontend/.next/static/chunks";
let bad = 0, checked = 0;
for (const f of fs.readdirSync(dir)) {
  if (!f.endsWith(".js")) continue;
  checked++;
  try { new Function(fs.readFileSync(path.join(dir, f), "utf8")); }
  catch (e) { bad++; if (bad <= 5) console.log("SYNTAX_BAD:", f, e.message.slice(0, 100)); }
}
console.log("checked=" + checked + " bad=" + bad);
'
echo "== restarting next =="
docker exec autogpt supervisorctl -c /opt/autogpt/single-container/supervisor/supervisord.conf restart runtime:next 2>&1 | tail -2
