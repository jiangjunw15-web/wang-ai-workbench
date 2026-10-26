#!/bin/bash
set -x
IMG=significantgravitas/autogpt:latest
BASE=/app/autogpt_platform/backend/backend

docker rm -f autogpt 2>/dev/null || true

docker run -d \
  --name autogpt \
  --restart unless-stopped \
  --shm-size 2g \
  --ulimit nofile=65536:65536 \
  --log-driver json-file \
  --log-opt max-size=50m \
  --log-opt max-file=5 \
  -p 127.0.0.1:3000:3000 \
  -e AUTOGPT_PUBLIC_URL=http://localhost:3000 \
  -e AUTOGPT_PUBLISH_SKILLS=false \
  -e MAGPIE_BASE_URL=http://172.17.0.1:13425/v1 \
  -e MAGPIE_API_KEY=magpie \
  -e CHAT_USE_LOCAL=true \
  -e CHAT_BASE_URL=http://172.17.0.1:13425/v1 \
  -e CHAT_API_KEY=magpie \
  -e CHAT_FAST_STANDARD_MODEL=group/free \
  -e HTTP_PROXY=http://172.17.0.1:17897 \
  -e HTTPS_PROXY=http://172.17.0.1:17897 \
  -e NO_PROXY=localhost,127.0.0.1,172.17.0.1,db,postgres,rabbitmq,valkey,falkordb,autogpt_rest,autogpt_frontend,autogpt_websocket \
  -e AUTH_ALLOW_NEW_ACCOUNTS=false \
  -e POSTHOG_API_KEY= \
  -e POSTHOG_HOST= \
  -e LANGFUSE_PUBLIC_KEY= \
  -e LANGFUSE_SECRET_KEY= \
  -e SENTRY_DSN= \
  -e GRAPHITI_TELEMETRY_ENABLED=false \
  -e MEM0_TELEMETRY=false \
  -e STRIPE_API_KEY= \
  -e STRIPE_WEBHOOK_SECRET= \
  -e POSTMARK_SERVER_API_TOKEN= \
  -e POSTMARK_WEBHOOK_TOKEN= \
  -e MAILERLITE_API_TOKEN= \
  -e TYPESAFE_API_KEY= \
  -v autogpt-data:/data \
  -v wang-frontend:/app/frontend \
  -v /root/agpt-patch/providers_integrations.py:$BASE/integrations/providers.py:ro \
  -v /root/agpt-patch/llm_blocks.py:$BASE/blocks/llm.py:ro \
  -v /root/agpt-patch/llm_providers.py:$BASE/util/llm/providers.py:ro \
  -v /root/agpt-patch/catalog.py:$BASE/data/llm_registry/catalog.py:ro \
  -v /root/agpt-patch/llm_models.py:$BASE/data/llm_registry/llm_models.py:ro \
  -v /root/agpt-patch/block_cost_config.py:$BASE/data/block_cost_config.py:ro \
  $IMG

echo "== waiting for health (up to 15 min) =="
for i in $(seq 1 90); do
  sleep 10
  ST=$(docker inspect --format '{{.State.Health.Status}}' autogpt 2>/dev/null || echo starting)
  if [ "$ST" = "healthy" ]; then
    echo "T+$((i*10))s PLATFORM_HEALTHY"
    docker logs autogpt 2>&1 | grep -E "bootstrap complete|ready" | tail -3
    exit 0
  fi
  if [ "$ST" = "unhealthy" ]; then
    echo "T+$((i*10))s PLATFORM_UNHEALTHY"
    docker logs autogpt --tail 30 2>&1 | tail -20
    exit 1
  fi
  if [ $((i % 12)) -eq 0 ]; then echo "T+$((i*10))s still $ST"; fi
done
echo PLATFORM_TIMEOUT
