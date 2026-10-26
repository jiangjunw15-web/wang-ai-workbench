#!/bin/bash
python3 - <<'PYEOF'
import json
d = json.load(open("/tmp/b.json"))
for b in d:
    bt = b.get("blockType") or b.get("block_type")
    name = b.get("name") or ""
    if bt == "INPUT" or name in ("Input Block", "Store Input Block") or "input" in name.lower() and "web" not in name.lower():
        props = list((b.get("inputSchema") or {}).get("properties", {}).keys())
        outp = list((b.get("outputSchema") or {}).get("properties", {}).keys())
        print(b.get("id"), "|", name, "| in:", props, "| out:", outp)
PYEOF
