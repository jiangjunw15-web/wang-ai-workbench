#!/bin/bash
set -x
EMAIL="coldcoffee@magpie.local"
PASS="AutoGPT#Magpie2026"
NAME="冷咖啡AI团队"
echo "== signup =="
curl -s -m 30 -X POST http://127.0.0.1:3000/api/auth/sign-up/email \
  -H "Content-Type: application/json" \
  -c /root/auth.cookies \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\",\"name\":\"$NAME\"}" | head -c 600
echo
echo "== session check =="
curl -s -m 20 -b /root/auth.cookies http://127.0.0.1:3000/api/auth/get-session | head -c 400
echo
