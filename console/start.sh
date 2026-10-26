#!/bin/bash
# Start the Wang console service on the Windows host (idempotent).
# All site-specific values come from environment variables with safe defaults,
# so this works from any checkout on any machine.
set -euo pipefail
WANG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${WANG_LOG_DIR:-$WANG_ROOT/console}"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/wang.log"

PORT="${WANG_PORT:-8790}"

# Already running? probe the state endpoint before starting a second instance.
if curl -s -m 3 -o /dev/null "http://127.0.0.1:$PORT/wang/api/state"; then
  echo "ALREADY_RUNNING"
  exit 0
fi

export MAGPIE_BASE_URL="${MAGPIE_BASE_URL:-http://127.0.0.1:13425/v1}"
export WANG_PORT="$PORT"
# State defaults to %LOCALAPPDATA%\wang-workbench (see wang_service.py);
# override with WANG_STATE if you want it elsewhere.
nohup python "$WANG_ROOT/console/wang_service.py" > "$LOG" 2>&1 &
sleep 3
curl -s -m 6 -o /dev/null -w "wang_service: %{http_code}\n" "http://127.0.0.1:$PORT/wang/api/state"
tail -3 "$LOG" 2>/dev/null || true
