#!/bin/bash
set -euo pipefail
. /root/autogpt_account.env
python3 - <<'PYEOF'
import json
d = json.load(open("/tmp/b.json"))
hits = []
for b in d:
    s = json.dumps(b)
    if "group/free" in s:
        hits.append(b.get("name") or b.get("id"))
print("blocks containing group/free:", len(hits))
for h in hits[:10]:
    print(" -", h)
ai = [b for b in d if b.get("categories") and "AI" in b.get("categories", [])]
print("AI-category blocks:", len(ai))
for b in ai[:8]:
    print(" *", b.get("name"))
# dump AI Text-ish block model enum
for b in d:
    if b.get("name") and "Text" in b["name"] and "LLM" in s if False else False:
        pass
PYEOF
