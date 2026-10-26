#!/bin/bash
set -euo pipefail
. /root/autogpt_account.env
KEY="$API_KEY"
ROW=$(docker exec -u postgres autogpt psql -h /var/run/postgresql -d postgres -t -A -F'|' -c 'SELECT hash, salt, status, permissions FROM platform."APIKey" WHERE name=$q$magpie-team-key$q$ LIMIT 1')
echo "row(head): ${ROW:0:60}..."
export KEY ROW
docker exec -i -e KEY="$KEY" -e ROW="$ROW" autogpt python - <<'PYEOF'
import os, sys
sys.path.insert(0, "/app/autogpt_platform/autogpt_libs")
from autogpt_libs.api_key.keysmith import APIKeySmith
key = os.environ["KEY"]
hash_, salt, status, perms = os.environ["ROW"].split("|", 3)
print("status:", status)
print("prefix ok:", key.startswith("agpt_"))
print("verify:", APIKeySmith().verify_key(key, hash_, salt))
PYEOF
