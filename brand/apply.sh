#!/bin/bash
# Full branding pipeline for 王将军AI工作台.
#   1. brand assets (logo / favicon)
#   2. ice-blue theme tokens
#   3. brand strings
#   4. sidebar (AI 排序管理 / Magpie 连接) + free-mode
#   5. rename patched chunks so browsers fetch them (cache-busting)
#   6. nginx revalidation rule
#   7. syntax check + restart
set -euo pipefail

echo "== 1/8 brand assets (logo / favicon) =="
docker cp /mnt/d/automate/brand/logo.svg autogpt:/app/frontend/public/wang-logo.svg
docker cp /mnt/d/automate/brand/favicon.svg autogpt:/app/frontend/public/wang-favicon.svg
docker cp /mnt/d/automate/brand/make_logos.py autogpt:/tmp/make_logos.py
docker exec autogpt python /tmp/make_logos.py
# favicon.ico: an ICO carrying our mark, so the tab icon matches.
docker exec autogpt python - <<'PYEOF'
from pathlib import Path
pub = Path("/app/frontend/public")
png = (pub / "wang-favicon.svg")
# Build a minimal single-image ICO from a 32x32 PNG rendered by make_logos.
import struct, zlib
def png_bytes(size):
    rows = []
    for y in range(size):
        row = b"\x00"
        for x in range(size):
            inside = True
            cx = min(max(x, 6), size - 7)
            cy = min(max(y, 6), size - 7)
            inside = (x - cx) ** 2 + (y - cy) ** 2 <= 36
            row += bytes((56, 189, 248, 255) if inside else (0, 0, 0, 0))
        rows.append(row)
    raw = b"".join(rows)
    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
img = png_bytes(32)
ico = struct.pack("<HHH", 0, 1, 1) + struct.pack("<BBBBHHII", 32, 32, 0, 0, 1, 32, len(img), 22) + img
for name in ("favicon.ico", "favicon-local.ico"):
    p = pub / name
    if p.exists():
        p.write_bytes(ico)
        print("wrote", name)
PYEOF

echo "== 2/8 theme tokens =="
docker cp /mnt/d/automate/brand/theme_tokens.py autogpt:/tmp/theme_tokens.py
docker exec autogpt python /tmp/theme_tokens.py

echo "== 3/8 brand strings =="
docker cp /mnt/d/automate/brand/patch_brand.py autogpt:/tmp/patch_brand.py
docker exec autogpt python /tmp/patch_brand.py || true

echo "== 4/8 sidebar + free-mode =="
docker cp /mnt/d/automate/brand/patch_sidebar.py autogpt:/tmp/patch_sidebar.py
docker exec autogpt python /tmp/patch_sidebar.py || true

echo "== 4b/8 free-mode (payments / telemetry / cookie consent) =="
docker cp /mnt/d/automate/brand/patch_free.py autogpt:/tmp/patch_free.py
docker exec autogpt python /tmp/patch_free.py || true

echo "== 5/8 cache-bust rename (static only; server keeps conventional paths) =="
docker cp /mnt/d/automate/brand/restore_names.py autogpt:/tmp/restore_names.py
docker exec autogpt python /tmp/restore_names.py || true
docker cp /mnt/d/automate/brand/rename_chunks.py autogpt:/tmp/rename_chunks.py
docker exec autogpt python /tmp/rename_chunks.py || true

echo "== 6/8 nginx revalidation =="
docker cp /mnt/d/automate/brand/nginx_patch.py autogpt:/tmp/nginx_patch.py
docker exec autogpt python /tmp/nginx_patch.py || true
docker exec autogpt nginx -t -c /opt/autogpt/single-container/nginx/nginx.conf 2>&1 | tail -1

echo "== 7/8 syntax check =="
docker exec -i autogpt node -e '
const fs = require("fs");
const path = require("path");
const dir = "/app/frontend/.next/static/chunks";
let bad = 0, checked = 0;
function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) { walk(p); continue; }
    if (!e.name.endsWith(".js")) continue;
    checked++;
    try { new Function(fs.readFileSync(p, "utf8")); }
    catch (err) { bad++; if (bad <= 3) console.log("SYNTAX_BAD:", p, err.message.slice(0, 80)); }
  }
}
walk(dir);
console.log("checked=" + checked + " bad=" + bad);
'

echo "== 8/8 restart =="
docker exec autogpt supervisorctl -c /opt/autogpt/single-container/supervisor/supervisord.conf restart runtime:nginx 2>&1 | tail -1
docker exec autogpt supervisorctl -c /opt/autogpt/single-container/supervisor/supervisord.conf restart runtime:next 2>&1 | tail -1
echo "BRAND_APPLIED"
