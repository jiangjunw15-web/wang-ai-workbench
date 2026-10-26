#!/bin/bash
set -x
EMAIL="coldcoffee@magpie.local"

# credentials generated at first run, stored locally outside source code
if [ -f /root/autogpt_account.env ]; then
  . /root/autogpt_account.env
else
  PASS="$(openssl rand -hex 12 2>/dev/null || head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  umask 077
  printf 'EMAIL=%s\nPASS=%s\n' "$EMAIL" "$PASS" > /root/autogpt_account.env
  chmod 600 /root/autogpt_account.env
  umask 022
  . /root/autogpt_account.env
fi

# 1) wait for frontend
CODE=000
for i in $(seq 1 30); do
  CODE=$(curl -s -m 6 -o /dev/null -w '%{http_code}' http://127.0.0.1:3000/)
  [ "$CODE" = "200" ] && break
  sleep 5
done
echo "frontend=$CODE"

# 2) signup (ignore "user already exists")
SIGNUP=$(curl -s -m 30 -X POST http://127.0.0.1:3000/api/auth/sign-up/email \
  -H "Content-Type: application/json" \
  -c /root/auth.cookies \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\",\"name\":\"ColdCoffee AI Team\"}")
echo "SIGNUP: $SIGNUP" | head -c 400; echo

# 3) session -> user id (sign-in first to be safe)
curl -s -m 30 -X POST http://127.0.0.1:3000/api/auth/sign-in/email \
  -H "Content-Type: application/json" -c /root/auth.cookies \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}" > /dev/null
SESSION=$(curl -s -m 20 -b /root/auth.cookies http://127.0.0.1:3000/api/auth/get-session)
echo "SESSION: ${SESSION:0:200}"
USER_ID=$(echo "$SESSION" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['user']['id'])" 2>/dev/null)
echo "USER_ID=$USER_ID"
[ -z "$USER_ID" ] && { echo "NO_USER_ID"; exit 1; }

# 4) promote to admin (best-effort)
docker exec autogpt autogpt-admin promote "$EMAIL" 2>&1 | tail -2 || true

# 5) mint API key via backend's own routine
docker cp /mnt/d/automate/wsl/mkkey.py autogpt:/tmp/mkkey.py
KEYOUT=$(docker exec autogpt python /tmp/mkkey.py "$USER_ID")
echo "$KEYOUT" | grep -v '^API_KEY:' | head -3
API_KEY_LINE=$(echo "$KEYOUT" | grep '^API_KEY:')
API_KEY="${API_KEY_LINE#API_KEY: }"
[ -z "$API_KEY" ] && { echo "NO_API_KEY"; exit 1; }
umask 077
printf 'API_KEY=%s\n' "$API_KEY" > /root/autogpt_account.env
chmod 600 /root/autogpt_account.env
umask 022

# 6) verify external API auth (print user info only, not the key)
curl -s -m 20 -H "X-API-Key: $API_KEY" http://127.0.0.1:3000/_agpt/external-api/v1/user | head -c 300; echo
echo "SETUP_DONE"
