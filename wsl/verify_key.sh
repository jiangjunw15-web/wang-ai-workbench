#!/bin/bash
set -euo pipefail
. /root/autogpt_account.env
echo "KEYLEN=${#API_KEY}"
curl -s -m 20 -H "X-API-Key: $API_KEY" http://127.0.0.1:3000/_agpt/external-api/v1/blocks -o /tmp/b.json -w "blocks:%{http_code}\n"
python3 - <<'PYEOF'
import json
d = json.load(open("/tmp/b.json"))
print("blocks:", len(d))
tg = [b for b in d if b.get("name") == "AI Text Generator"]
print("AITextGen:", len(tg))
if tg:
    s = json.dumps(tg[0]["inputSchema"])
    for m in ["group/free", "group/kimi", "group/micu", "group/deepseek",
              "auto/deepseek-v4-flash", "auto/minimax-m3.1-flash", "deepseek/deepseek-v4-flash"]:
        print(m, "->", m in s)
PYEOF
