#!/bin/bash
set -euo pipefail
. /root/autogpt_account.env
GID=$(sed -n 1p /root/team_graph_id)
EID="31e06cc0-2619-4bfc-8feb-bd011b286219"
curl -s -m 20 -H "X-API-Key: $API_KEY" "http://127.0.0.1:3000/_agpt/external-api/v1/graphs/$GID/executions/$EID/results" -o /tmp/res.json
python3 - <<'PYEOF'
import json
d = json.load(open("/tmp/res.json"))
print("status:", d.get("status"), "| nodes:", len(d.get("nodes", [])))
for n in d.get("nodes", []):
    out = n.get("output") or {}
    keys = {k: type(v).__name__ for k, v in out.items()} if isinstance(out, dict) else type(out).__name__
    print("node:", n.get("node_id"), "| out_keys:", keys if isinstance(keys, dict) else keys)
resp = None
for n in d.get("nodes", []):
    out = n.get("output") or {}
    r = out.get("response")
    if isinstance(r, list) and r and isinstance(r[-1], str):
        txt = "".join(x for x in r if isinstance(x, str))
        if len(txt) > len(resp or ""):
            resp = txt
print("LONGEST RESPONSE len:", len(resp or ""))
print((resp or "")[:500])
PYEOF
