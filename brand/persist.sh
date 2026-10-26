#!/bin/bash
# Persist the branded frontend bundle into a Docker volume so the 王将军
# customisation survives container recreation (needed when adding env vars).
#
#   1. copy /app/frontend OUT OF THE RUNNING (branded) container
#   2. store it in the wang-frontend volume
#   3. report what the volume holds
set -euo pipefail
VOL=wang-frontend
STAGE=/root/wang-frontend-stage

echo "== 1. stage the branded frontend =="
rm -rf "$STAGE"
mkdir -p "$STAGE"
docker cp autogpt:/app/frontend/. "$STAGE"/
echo "staged: $(du -sh "$STAGE" | cut -f1)"
ls "$STAGE" | head -6

echo "== 2. write into the volume =="
docker volume create "$VOL" >/dev/null
docker run --rm -v "$VOL":/target -v "$STAGE":/src:ro alpine:3.20 \
  sh -c 'rm -rf /target/* && cp -a /src/. /target/ && echo VOLUME_FILLED'
docker run --rm -v "$VOL":/t alpine:3.20 sh -c 'du -sh /t | cut -f1; ls /t | head -6'
rm -rf "$STAGE"

echo "PERSISTED"
