#!/bin/bash
set -x
docker cp /mnt/d/automate/wsl/mkkey.py autogpt:/tmp/mkkey.py
OUT=$(docker exec autogpt python /tmp/mkkey.py 44316809-a56c-454b-81c7-0de20edb0cf3 2>&1)
echo "$OUT" | grep -E "KEY_ID|Error" | head -3
echo "$OUT" | grep -vE "Acquiring|Releasing|INFO|WARNING|Prisma-" | tail -6
if ! grep -q API_KEY /root/autogpt_account.env; then
  KEY=$(echo "$OUT" | grep '^API_KEY:' | sed 's/^API_KEY: //')
  if [ -n "$KEY" ]; then
    umask 077
    printf 'API_KEY=%s\n' "$KEY" >> /root/autogpt_account.env
    chmod 600 /root/autogpt_account.env
    umask 022
  fi
fi
grep -q API_KEY /root/autogpt_account.env && echo KEY_SAVED || echo KEY_MISSING
