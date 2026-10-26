#!/bin/bash
set -euo pipefail
curl -s -m 15 http://localhost:3000/ -o /tmp/h.html
echo "size=$(stat -c %s /tmp/h.html)"
echo "title_zh=$(grep -c '王将军AI工作台' /tmp/h.html || true)"
echo "title_en_autogptplatform=$(grep -c 'AutoGPT Platform' /tmp/h.html || true)"
echo "desc_zh=$(grep -c '专属 AI 创作与自动化工作台' /tmp/h.html || true)"
echo "agpt_co=$(grep -c 'agpt.co' /tmp/h.html || true)"
echo "logo_wang=$(grep -c 'wang-logo' /tmp/h.html || true)"
