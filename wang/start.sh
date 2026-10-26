#!/bin/bash
# Start the 王将军 local console service (Windows host) and keep it alive.
set -euo pipefail
LOG=/d/automate/wang/wang.log
mkdir -p /d/automate/wang

if tasklist //FI "IMAGENAME eq python.exe" 2>/dev/null | grep -qi python; then
  # already running — check the port before starting a second one
  if curl -s -m 3 -o /dev/null http://127.0.0.1:8790/wang/api/state; then
    echo "ALREADY_RUNNING"
    exit 0
  fi
fi

export MAGPIE_BASE_URL="http://127.0.0.1:13425/v1"
export WANG_STATE="D:\\automate\\ai-order.json"
export WANG_PORT=8790
nohup python /d/automate/wang/wang_service.py > "$LOG" 2>&1 &
sleep 3
curl -s -m 6 -o /dev/null -w "wang_service: %{http_code}\n" http://127.0.0.1:8790/wang/api/state
tail -3 "$LOG" 2>/dev/null
