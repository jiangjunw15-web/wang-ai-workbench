#!/bin/bash
# Sign in via the platform API and print the session token + user id.
set -euo pipefail
. /root/autogpt_account.env
curl -s -m 20 -X POST http://127.0.0.1:3000/api/auth/sign-in/email \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}" -o /tmp/signin.json
python3 - <<'PY'
import json
d = json.load(open("/tmp/signin.json"))
print("TOKEN=" + d.get("token", ""))
print("USERID=" + d["user"]["id"])
print("ROLE=" + str(d["user"].get("role")))
PY
