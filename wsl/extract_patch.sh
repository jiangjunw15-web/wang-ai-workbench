#!/bin/bash
set -e
IMG=significantgravitas/autogpt:latest
BASE=/app/autogpt_platform/backend/backend
echo "== verify paths in image =="
docker run --rm --entrypoint sh $IMG -c "ls $BASE/blocks/llm.py $BASE/util/llm/providers.py $BASE/data/llm_registry/catalog.py $BASE/data/llm_registry/llm_models.py $BASE/data/block_cost_config.py $BASE/integrations/providers.py" || { echo PATHS_DIFFER; docker run --rm --entrypoint sh $IMG -c "find /app -maxdepth 4 -name llm_registry -o -maxdepth 4 -name blocks -type d" | head; exit 1; }

echo "== extract =="
rm -rf /root/agpt-patch && mkdir -p /root/agpt-patch
CID=$(docker create $IMG true)
docker cp $CID:$BASE/integrations/providers.py /root/agpt-patch/providers_integrations.py
docker cp $CID:$BASE/blocks/llm.py /root/agpt-patch/llm_blocks.py
docker cp $CID:$BASE/util/llm/providers.py /root/agpt-patch/llm_providers.py
docker cp $CID:$BASE/data/llm_registry/catalog.py /root/agpt-patch/catalog.py
docker cp $CID:$BASE/data/llm_registry/llm_models.py /root/agpt-patch/llm_models.py
docker cp $CID:$BASE/data/block_cost_config.py /root/agpt-patch/block_cost_config.py
docker rm $CID > /dev/null
ls -la /root/agpt-patch

echo "== apply patch =="
python3 /mnt/d/automate/wsl/patch_magpie.py /root/agpt-patch

echo "== validate import in throwaway container =="
docker run --rm \
  -v /root/agpt-patch/providers_integrations.py:$BASE/integrations/providers.py:ro \
  -v /root/agpt-patch/llm_blocks.py:$BASE/blocks/llm.py:ro \
  -v /root/agpt-patch/llm_providers.py:$BASE/util/llm/providers.py:ro \
  -v /root/agpt-patch/catalog.py:$BASE/data/llm_registry/catalog.py:ro \
  -v /root/agpt-patch/llm_models.py:$BASE/data/llm_registry/llm_models.py:ro \
  -v /root/agpt-patch/block_cost_config.py:$BASE/data/block_cost_config.py:ro \
  -e MAGPIE_BASE_URL=http://172.17.0.1:13425/v1 \
  --entrypoint python $IMG -c "
import sys
sys.path.insert(0, '/app/autogpt_platform/backend')
from backend.data.llm_registry.llm_models import LLMModel
mag = [m.value for m in LLMModel if m.value.startswith(('group/','auto/','deepseek/'))]
print('MAGPIE_MODELS:', mag)
from backend.blocks.llm import LLMProviderName, AICredentialsField
print('LLMProviderName ok:', 'magpie' in str(LLMProviderName))
from backend.data.block_cost_config import LLM_COST
print('COST_CONFIG_OK')
print('VALIDATE_DONE')
"
