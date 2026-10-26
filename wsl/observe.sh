#!/bin/bash
for i in $(seq 1 50); do
  UP=$(docker ps --format '{{.Status}}' --filter name=autogpt 2>/dev/null | head -1)
  SEC=$(echo "$UP" | grep -oE 'Up [0-9]+' | grep -oE '[0-9]+')
  if [ -n "$SEC" ] && [ "$SEC" -ge 80 ] && [ "$SEC" -le 170 ]; then
    echo "=== window at up=${SEC}s ==="
    echo "--- supervisor status ---"
    docker exec autogpt supervisorctl -c /opt/autogpt/single-container/supervisor/supervisord.conf status 2>&1 | head -26
    echo "--- runtime logs dir ---"
    docker exec autogpt sh -c 'ls /data/runtime/ 2>/dev/null | head; ls /data/logs 2>/dev/null | head'
    echo "--- recent per-program logs with errors ---"
    docker exec autogpt sh -c 'grep -rE "Traceback|FATAL|Error|exited" /data/runtime/*.log 2>/dev/null | tail -8; for f in /data/logs/*.log; do tail -3 "$f" 2>/dev/null | grep -E "Traceback|Error|FATAL" && echo "(in $f)"; done 2>/dev/null | head -12'
    exit 0
  fi
  sleep 4
done
echo "WINDOW_NOT_CAUGHT"
