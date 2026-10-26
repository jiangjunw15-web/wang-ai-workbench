#!/bin/bash
set -euo pipefail
. /root/autogpt_account.env
echo "team_graph_id file:"; cat /root/team_graph_id 2>/dev/null || echo "(missing)"
echo "--- graphs in library ---"
docker exec -u postgres autogpt psql -h /var/run/postgresql -d postgres -t -A -F'|' -c \
  'SELECT g.id, g.name, g."isActive", (l.id IS NOT NULL) AS in_library FROM platform."AgentGraph" g LEFT JOIN platform."LibraryAgent" l ON l."agentGraphId"=g.id ORDER BY g."createdAt";'
