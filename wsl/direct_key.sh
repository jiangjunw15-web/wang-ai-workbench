#!/bin/bash
# Generate an API key with the official keysmith algorithm inside the container
# and insert the record directly via psql (prisma-free path). SQL is generated
# by a local python formatter and piped to psql over stdin.
set -euo pipefail
USER_ID="44316809-a56c-454b-81c7-0de20edb0cf3"

docker cp /mnt/d/automate/wsl/genkey.py autogpt:/tmp/genkey.py
GEN=$(docker exec autogpt python /tmp/genkey.py)
PGPASS=$(docker exec autogpt sh -c 'tr "\0" "\n" < /proc/1/environ | grep "^POSTGRES_PASSWORD=" | cut -d= -f2-')

export GEN PGPASS USER_ID
SQLFILE=$(python3 - <<'PYEOF'
import json, os, uuid, tempfile

gen = json.loads(os.environ["GEN"])
kid = str(uuid.uuid4())
perms = [
    "IDENTITY", "EXECUTE_GRAPH", "READ_GRAPH", "WRITE_GRAPH", "EXECUTE_BLOCK",
    "READ_BLOCK", "READ_STORE", "WRITE_LIBRARY", "USE_TOOLS",
    "MANAGE_INTEGRATIONS", "READ_INTEGRATIONS", "DELETE_INTEGRATIONS",
]
perm_list = ",".join(f"'{p}'" for p in perms)
sql = (
    'INSERT INTO platform."APIKey" '
    '(id,name,head,tail,hash,salt,status,permissions,description,"userId") VALUES ('
    f"'{kid}','magpie-team-key','{gen['head']}','{gen['tail']}',"
    f"'{gen['hash']}','{gen['salt']}','ACTIVE',"
    f"ARRAY[{perm_list}]::platform.\"APIKeyPermission\"[],"
    f"'AI team full access key created by local setup','{os.environ['USER_ID']}');"
)
fd, path = tempfile.mkstemp(suffix=".sql")
with os.fdopen(fd, "w") as f:
    f.write(sql)
print(path)
with open(path, "a") as f:
    pass
with open(path) as f:
    content = f.read()
# keep the plaintext key for the caller via a side channel file
with open("/tmp/team_plainkey.txt", "w") as f:
    f.write(gen["key"])
PYEOF
)

docker exec -i -u postgres autogpt psql -h /var/run/postgresql -d postgres < "$SQLFILE"
rm -f "$SQLFILE"

KEY=$(cat /tmp/team_plainkey.txt)
rm -f /tmp/team_plainkey.txt
if ! grep -q API_KEY /root/autogpt_account.env; then
  umask 077
  printf 'API_KEY=%s\n' "$KEY" >> /root/autogpt_account.env
  chmod 600 /root/autogpt_account.env
  umask 022
fi
grep -q API_KEY /root/autogpt_account.env && echo KEY_SAVED || echo KEY_MISSING
