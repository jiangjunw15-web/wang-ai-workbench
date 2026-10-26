#!/bin/bash
echo "== supervisor status =="
docker exec autogpt supervisorctl -c /opt/autogpt/single-container/supervisor/supervisord.conf status 2>&1 | head -24
echo "== ready marker =="
docker exec autogpt sh -c 'ls /data/runtime/ 2>/dev/null | head -8; ls /opt/autogpt/single-container/ | head -5; env | grep -i "AUTOGPT_.*DIR\|RUNTIME" | head -6'
echo "== manual publish run =="
docker exec autogpt sh -c 'cd /app/autogpt_platform/backend && timeout 120 .venv/bin/python -m backend.cli.publish_skills_catalog --skip-missing-preloads 2>&1 || timeout 120 publish-skills-catalog --skip-missing-preloads 2>&1' | head -30
echo "PUBLISH_RC=$?"
