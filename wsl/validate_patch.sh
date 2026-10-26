#!/bin/bash
set -e
IMG=significantgravitas/autogpt:latest
BASE=/app/autogpt_platform/backend/backend
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
assert 'group/free' in mag
from backend.blocks.llm import LLMProviderName
print('LLMProviderName ok:', 'magpie' in str(LLMProviderName))
from backend.data.block_cost_config import LLM_COST
print('COST_CONFIG_OK')
from backend.integrations.providers import ProviderName
print('PROVIDER_ENUM:', ProviderName.MAGPIE.value)
print('VALIDATE_DONE')
"
