#!/bin/bash
# Verify the stored password against the platform's sign-in endpoint.
set -euo pipefail
. /root/autogpt_account.env
CODE=$(curl -s -m 20 -o /tmp/signin.json -w '%{http_code}' -X POST \
  http://127.0.0.1:3000/api/auth/sign-in/email \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}")
echo "SIGNIN_HTTP=$CODE"
head -c 200 /tmp/signin.json
echo
