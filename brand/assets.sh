#!/bin/bash
# Copy the 王将军 brand assets into the platform's public dir (persistent volume).
set -euo pipefail
docker cp /mnt/d/automate/brand/wang-wordmark.svg autogpt:/app/frontend/public/wang-wordmark.svg
docker cp /mnt/d/automate/brand/logo.svg autogpt:/app/frontend/public/wang-logo.svg
docker exec autogpt ls -la /app/frontend/public/wang-wordmark.svg /app/frontend/public/wang-logo.svg
docker exec autogpt curl -s -o /dev/null -w "wordmark: %{http_code}\n" http://127.0.0.1:3000/wang-wordmark.svg
docker exec autogpt curl -s -o /dev/null -w "logo: %{http_code}\n" http://127.0.0.1:3000/wang-logo.svg
