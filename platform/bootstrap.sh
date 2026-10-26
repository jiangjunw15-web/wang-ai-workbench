#!/bin/bash
# Bootstrap the AutoGPT Platform inside a WSL distro and wire it to an
# OpenAI-compatible LLM gateway (Magpie or any other).
#
# Everything site-specific comes from environment variables; nothing here is
# tied to a particular machine. Defaults use generic names so a fresh install
# is self-consistent.
#
#   WSL_DISTRO     WSL distribution name            (default: wang-workbench)
#   CONTAINER      Docker container name            (default: wang-workbench)
#   IMAGE          Docker image to run              (default: significantgravitas/autogpt:latest)
#   GATEWAY_HOST   host the LLM gateway is reachable at from the container
#                  (default: 172.17.0.1, the Docker bridge gateway)
#   GATEWAY_PORT   gateway port inside the relay    (default: 13425)
#   MODELS_JSON    path to a JSON list of model ids to register (optional)
set -euo pipefail

WSL_DISTRO="${WSL_DISTRO:-wang-workbench}"
CONTAINER="${CONTAINER:-wang-workbench}"
IMAGE="${IMAGE:-significantgravitas/autogpt:latest}"
GATEWAY_HOST="${GATEWAY_HOST:-172.17.0.1}"
GATEWAY_PORT="${GATEWAY_PORT:-13425}"
MODELS_JSON="${MODELS_JSON:-}"

echo "== 1. ensure WSL distro =="
if ! wsl.exe -l -q 2>/dev/null | grep -qx "$WSL_DISTRO"; then
  echo "distro '$WSL_DISTRO' not found; import an Ubuntu rootfs first, e.g.:"
  echo "  wsl --import $WSL_DISTRO <install-dir> <ubuntu-rootfs.tar.gz> --version 2"
  exit 1
fi

echo "== 2. ensure docker inside the distro =="
wsl.exe -d "$WSL_DISTRO" -u root -- bash -c 'command -v docker >/dev/null || { echo "docker missing; install docker-ce first"; exit 1; }'

echo "== 3. run the platform container =="
wsl.exe -d "$WSL_DISTRO" -u root -- docker rm -f "$CONTAINER" 2>/dev/null || true
wsl.exe -d "$WSL_DISTRO" -u root -- docker run -d \
  --name "$CONTAINER" \
  --restart unless-stopped \
  --shm-size 2g \
  -p 127.0.0.1:3000:3000 \
  -e AUTOGPT_PUBLIC_URL=http://localhost:3000 \
  -e AUTOGPT_PUBLISH_SKILLS=false \
  -e "MAGPIE_BASE_URL=http://${GATEWAY_HOST}:${GATEWAY_PORT}/v1" \
  -e MAGPIE_API_KEY="${MAGPIE_API_KEY:-}" \
  -e CHAT_USE_LOCAL=true \
  -e "CHAT_BASE_URL=http://${GATEWAY_HOST}:${GATEWAY_PORT}/v1" \
  -e CHAT_API_KEY="${MAGPIE_API_KEY:-}" \
  -v "${CONTAINER}-data:/data" \
  "$IMAGE"

echo "== 4. apply the gateway LLM-provider patch =="
# patch_magpie.py adds an OpenAI-compatible provider + registers models from
# $MODELS_JSON (if given) into the platform's LLM catalog.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
wsl.exe -d "$WSL_DISTRO" -u root -- bash -c "
  docker cp '$SCRIPT_DIR/patch_magpie.py' '$CONTAINER':/tmp/patch_magpie.py
  docker exec -e MODELS_JSON='$MODELS_JSON' '$CONTAINER' python /tmp/patch_magpie.py
"

echo "== done =="
echo "open http://localhost:3000 once the container is healthy:"
echo "  wsl -d $WSL_DISTRO -u root -- docker inspect --format '{{.State.Health.Status}}' $CONTAINER"
