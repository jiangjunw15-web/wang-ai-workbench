#!/bin/bash
set -euo pipefail
docker cp /mnt/d/automate/brand/patch_logo_svg.py autogpt:/tmp/patch_logo_svg.py
docker exec autogpt python /tmp/patch_logo_svg.py
docker exec autogpt supervisorctl -c /opt/autogpt/single-container/supervisor/supervisord.conf restart runtime:next 2>&1 | tail -1
