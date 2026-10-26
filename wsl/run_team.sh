#!/bin/bash
# Run the AI-Team workflow: create graph once, execute with an instruction, save the deliverable.
# Usage: run_team.sh "用户指令"
set -euo pipefail
INSTRUCTION="${1:?用法: run_team.sh \"指令\"}"
API="http://127.0.0.1:3000/_agpt/external-api/v1"

. /root/autogpt_account.env
AUTH="X-API-Key: ${API_KEY}"

# 1) create graph once
if [ ! -f /root/team_graph_id ]; then
  OUT=$(TEAM_TOKEN="$API_KEY" python3 /mnt/d/automate/wsl/team_graph.py) || { echo "$OUT"; exit 1; }
  echo "$OUT"
  GID=$(echo "$OUT" | grep '^GRAPH_ID:' | cut -d' ' -f2)
  VER=$(echo "$OUT" | grep '^GRAPH_VERSION:' | cut -d' ' -f2)
  [ -n "$GID" ] && printf '%s\n%s\n' "$GID" "$VER" > /root/team_graph_id
fi
if [ ! -f /root/team_graph_id ]; then
  echo "GRAPH_CREATE_FAILED"
  exit 1
fi
GID=$(sed -n 1p /root/team_graph_id)
VER=$(sed -n 2p /root/team_graph_id)
echo "graph=$GID version=$VER"

# 2) execute
PAYLOAD=$(printf '%s' "$INSTRUCTION" | jq -Rs '{node_input: {instruction: .}}')
EXEC=$(curl -s -m 30 -X POST -H "$AUTH" -H "Content-Type: application/json" \
  -d "$PAYLOAD" "$API/graphs/$GID/execute/$VER")
echo "EXEC: $EXEC"
EID=$(echo "$EXEC" | jq -r '.id')
[ "$EID" = "null" ] && { echo "EXEC_FAILED"; exit 1; }

# 3) poll results (editor node id captured at graph creation)
EDITOR_NODE=$(sed -n 3p /root/team_graph_id)
echo "editor_node=$EDITOR_NODE"
OUTDIR=/mnt/d/automate/outputs
mkdir -p "$OUTDIR"
for i in $(seq 1 45); do
  sleep 10
  RES=$(curl -s -m 20 -H "$AUTH" "$API/graphs/$GID/executions/$EID/results")
  STATUS=$(echo "$RES" | jq -r '.status' 2>/dev/null || echo "?")
  echo "T+$((i*10))s status=$STATUS"
  if [ "$STATUS" = "COMPLETED" ] || [ "$STATUS" = "TERMINATED" ] || [ "$STATUS" = "FAILED" ]; then
    if [ "$STATUS" = "COMPLETED" ]; then
      TS=$(date +%Y%m%d-%H%M%S)
      F="$OUTDIR/team-$TS.md"
      echo "$RES" | jq -r --arg n "$EDITOR_NODE" \
        '.nodes[] | select(.node_id==$n) | (.output.response // []) | map(tostring) | join("")' > "$F"
      if [ ! -s "$F" ]; then
        echo "$RES" | jq -r '(.nodes[-1].output.response // []) | map(tostring) | join("")' > "$F"
      fi
      echo "DELIVERABLE: $F"
      echo "--- preview ---"
      head -c 600 "$F"
      echo
    else
      echo "$RES" | head -c 1500
    fi
    exit 0
  fi
done
echo "TIMEOUT_WAITING_RESULTS"
exit 2
