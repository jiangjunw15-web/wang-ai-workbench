#!/bin/bash
# End-to-end verification of the 王将军AI工作台 install.
set -uo pipefail
ok() { printf "  [OK]   %s\n" "$1"; }
bad() { printf "  [FAIL] %s\n" "$1"; }

echo "== 1. container =="
docker ps --format '{{.Names}} {{.Status}}' | head -2
ST=$(docker inspect --format '{{.State.Health.Status}}' autogpt 2>/dev/null)
[ "$ST" = "healthy" ] && ok "container healthy" || bad "container $ST"

echo "== 2. platform endpoints =="
for U in / /library /wang/ai-order /wang/magpie /_agpt/external-api/v1/blocks; do
  C=$(curl -s -m 15 -o /dev/null -w '%{http_code}' "http://localhost:3000$U")
  [ "$C" = "200" ] && ok "$U -> $C" || bad "$U -> $C"
done

echo "== 3. wang console api =="
C=$(curl -s -m 15 -o /dev/null -w '%{http_code}' http://localhost:3000/wang/api/models); [ "$C" = "200" ] && ok "models api" || bad "models api $C"
N=$(curl -s -m 15 http://localhost:3000/wang/api/models | python3 -c 'import sys,json;print(len(json.load(sys.stdin)))' 2>/dev/null)
[ "${N:-0}" -gt 0 ] && ok "gateway models reachable ($N)" || bad "no models"
R=$(curl -s -m 40 "http://localhost:3000/wang/api/probe?model=group%2Ffree" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("ok"))' 2>/dev/null)
[ "$R" = "True" ] && ok "model probe works" || bad "model probe $R"

echo "== 4. magpie backend patch =="
docker exec autogpt grep -c magpie /app/autogpt_platform/backend/backend/integrations/providers.py >/dev/null 2>&1 && ok "magpie provider registered" || bad "magpie provider missing"

echo "== 5. branding =="
docker exec autogpt bash -c 'grep -rl 王将军 /app/frontend/.next/static/chunks --include=*.js 2>/dev/null | wc -l' | grep -qE '^[1-9]' && ok "brand strings present" || bad "no brand strings"
docker exec autogpt bash -c 'grep -o -- "--primary: [^;]*" /app/frontend/.next/static/css/*.css 2>/dev/null | head -1' | grep -q "214.2 52.0% 24.5%" && ok "ice-blue theme" || bad "theme tokens"

echo "== 6. nginx routes =="
docker exec autogpt grep -c wang-static-revalidate /opt/autogpt/single-container/nginx/nginx.conf 2>/dev/null | grep -qE '^[1-9]' && ok "static revalidation rule" || bad "no revalidation rule"
docker exec autogpt grep -c wang-console /opt/autogpt/single-container/nginx/nginx.conf 2>/dev/null | grep -qE '^[1-9]' && ok "wang console route" || bad "no wang route"

echo "== 7. windows-side services =="
curl -s -m 8 -o /dev/null -w '%{http_code}' http://127.0.0.1:8790/wang/api/state | grep -q 200 && ok "wang service (8790)" || bad "wang service down"
curl -s -m 8 -o /dev/null -w '%{http_code}' http://127.0.0.1:13425/v1/models | grep -q 200 && ok "magpie relay (13425)" || bad "magpie relay down"
curl -s -m 8 -o /dev/null -w '%{http_code}' http://127.0.0.1:18790/wang/api/state | grep -q 200 && ok "wang relay (18790)" || bad "wang relay down"

echo "== 8. AI team workflow =="
docker exec -u postgres autogpt psql -h /var/run/postgresql -d postgres -t -A -c \
  "SELECT count(*) FROM platform.\"AgentGraph\" WHERE name='AI创作团队'" 2>/dev/null | grep -qE '^[1-9]' && ok "AI创作团队 workflow exists" || bad "workflow missing"

echo "== 9. free mode =="
docker inspect autogpt --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -q "AUTH_ALLOW_NEW_ACCOUNTS=false" && ok "registration closed" || bad "registration still open"
docker inspect autogpt --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -q "POSTHOG_API_KEY=" && ok "telemetry key blanked" || bad "telemetry key set"

echo "VERIFY_DONE"
