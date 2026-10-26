#!/usr/bin/env python3
"""Apply the Magpie gateway integration patch to extracted AutoGPT backend files.

Usage: python3 patch_magpie.py <dir-with-extracted-files>
Files expected (flat names produced by extract step):
  providers_integrations.py  (backend/integrations/providers.py)
  llm_blocks.py              (backend/blocks/llm.py)
  llm_providers.py           (backend/util/llm/providers.py)
  catalog.py                 (backend/data/llm_registry/catalog.py)
  llm_models.py              (backend/data/llm_registry/llm_models.py)
  block_cost_config.py       (backend/data/block_cost_config.py)
"""
import sys
from pathlib import Path

D = Path(sys.argv[1])


def patch(fname: str, old: str, new: str, expect: int = 1) -> None:
    p = D / fname
    text = p.read_text(encoding="utf-8")
    n = text.count(old)
    if n != expect:
        raise SystemExit(f"[FAIL] {fname}: anchor found {n}x (expected {expect}):\n---\n{old[:200]}\n---")
    p.write_text(text.replace(old, new), encoding="utf-8")
    print(f"[OK] {fname}: patched")


# ---- 1) ProviderName enum: add MAGPIE ----
patch(
    "providers_integrations.py",
    '    OLLAMA = "ollama"\n',
    '    OLLAMA = "ollama"\n    MAGPIE = "magpie"\n',
)

# ---- 2) util/llm/providers.py: ProviderLiteral + dispatch branch + os import ----
patch(
    "llm_providers.py",
    'import asyncio\nimport functools\n',
    'import asyncio\nimport functools\nimport os\n',
)
patch(
    "llm_providers.py",
    '    "openai",\n    "anthropic",\n    "groq",\n    "ollama",\n',
    '    "openai",\n    "anthropic",\n    "groq",\n    "ollama",\n    "magpie",\n',
)
patch(
    "llm_providers.py",
    '''    if provider == "openai":
        return await _call_openai_responses(''',
    '''    if provider == "magpie":
        return await _call_openai_compat(
            base_url=os.getenv("MAGPIE_BASE_URL", "http://127.0.0.1:13425/v1"),
            model=model,
            api_key=api_key or os.getenv("MAGPIE_API_KEY", "magpie"),
            messages=messages,
            max_tokens=max_tokens,
            temperature=temperature,
            tools=tools,
            force_json_output=force_json_output,
            parallel_tool_calls=parallel_tool_calls,
            timeout_seconds=timeout_seconds,
            include_openrouter_extras=False,
        )
    if provider == "openai":
        return await _call_openai_responses(''',
)

# ---- 3) blocks/llm.py: provider Literal + credential-free set + runtime guard ----
patch(
    "llm_blocks.py",
    '    ProviderName.OLLAMA,\n    ProviderName.OPENAI,\n',
    '    ProviderName.OLLAMA,\n    ProviderName.MAGPIE,\n    ProviderName.OPENAI,\n',
)
patch(
    "llm_blocks.py",
    '            if allow_credential_free and model.metadata.provider == ProviderName.OLLAMA\n',
    '            if allow_credential_free and model.metadata.provider in (\n                ProviderName.OLLAMA,\n                ProviderName.MAGPIE,\n            )\n',
)
patch(
    "llm_blocks.py",
    '    if credentials is None and provider != ProviderName.OLLAMA:\n',
    '    if credentials is None and provider not in (ProviderName.OLLAMA, ProviderName.MAGPIE):\n',
)

# ---- 4) catalog.py: provider + creators + models ----
patch(
    "catalog.py",
    '            CatalogProvider(name="openai", display_name="OpenAI"),\n',
    '            CatalogProvider(name="openai", display_name="OpenAI"),\n'
    '            CatalogProvider(name="magpie", display_name="Magpie 网关"),\n',
)
patch(
    "catalog.py",
    '            CatalogCreator(name="xiaomi", display_name="Xiaomi"),\n',
    '            CatalogCreator(name="xiaomi", display_name="Xiaomi"),\n'
    '            CatalogCreator(name="micu", display_name="米醋中转站"),\n'
    '            CatalogCreator(name="opencode-zen", display_name="OpenCode Zen"),\n',
)

MAGPIE_MODELS = '''            # ----- Magpie Gateway (local) -----
            CatalogModel(
                slug="group/free",
                display_name="Magpie 免费 (GLM)",
                provider="magpie",
                creator="opencode-zen",
                context_window=1048576,
                max_output_tokens=524288,
                price_tier=1,
                cost=CatalogModelCost(run_credits=1),
            ),
            CatalogModel(
                slug="group/deepseek",
                display_name="Magpie DeepSeek",
                provider="magpie",
                creator="deepseek",
                context_window=1048576,
                max_output_tokens=393216,
                price_tier=1,
                cost=CatalogModelCost(run_credits=1),
            ),
            CatalogModel(
                slug="group/kimi",
                display_name="Magpie Kimi",
                provider="magpie",
                creator="moonshot-ai",
                context_window=1048576,
                max_output_tokens=1048576,
                price_tier=1,
                cost=CatalogModelCost(run_credits=1),
            ),
            CatalogModel(
                slug="group/micu",
                display_name="Magpie 米醋中转站",
                provider="magpie",
                creator="micu",
                context_window=1048576,
                max_output_tokens=384000,
                price_tier=1,
                cost=CatalogModelCost(run_credits=1),
            ),
            CatalogModel(
                slug="auto/deepseek-v4-flash",
                display_name="Magpie DeepSeek V4 Flash (Auto)",
                provider="magpie",
                creator="deepseek",
                context_window=1048576,
                price_tier=1,
                cost=CatalogModelCost(run_credits=1),
            ),
            CatalogModel(
                slug="auto/minimax-m3.1-flash",
                display_name="Magpie MiniMax M3.1 Flash (Auto)",
                provider="magpie",
                creator="deepseek",
                context_window=1048576,
                price_tier=1,
                cost=CatalogModelCost(run_credits=1),
            ),
            CatalogModel(
                slug="deepseek/deepseek-v4-flash",
                display_name="Magpie DeepSeek V4 Flash",
                provider="magpie",
                creator="deepseek",
                context_window=1048576,
                price_tier=1,
                cost=CatalogModelCost(run_credits=1),
            ),
'''

# Insert at the end of the models list (anchor: closing of _build_catalog return)
text = (D / "catalog.py").read_text(encoding="utf-8")
anchor = "\n        ],\n    )\n"
idx = text.rfind(anchor)
if idx == -1:
    raise SystemExit("[FAIL] catalog.py: models-list closing anchor not found")
text = text[:idx] + "\n" + MAGPIE_MODELS + text[idx:]
(D / "catalog.py").write_text(text, encoding="utf-8")
print("[OK] catalog.py: 7 magpie models inserted")

# ---- 5) llm_models.py: enum members ----
patch(
    "llm_models.py",
    "class LLMModel(str, Enum, metaclass=LLMModelMeta):\n",
    "class LLMModel(str, Enum, metaclass=LLMModelMeta):\n"
    "    # -- Magpie gateway models (added by local setup; see catalog.py) --\n"
    '    MAGPIE_GROUP_FREE = "group/free"\n'
    '    MAGPIE_GROUP_DEEPSEEK = "group/deepseek"\n'
    '    MAGPIE_GROUP_KIMI = "group/kimi"\n'
    '    MAGPIE_GROUP_MICU = "group/micu"\n'
    '    MAGPIE_AUTO_DEEPSEEK_V4_FLASH = "auto/deepseek-v4-flash"\n'
    '    MAGPIE_AUTO_MINIMAX_M31_FLASH = "auto/minimax-m3.1-flash"\n'
    '    MAGPIE_DEEPSEEK_V4_FLASH = "deepseek/deepseek-v4-flash"\n',
)

# ---- 6) block_cost_config.py: magpie = free (mirror ollama branch) ----
patch(
    "block_cost_config.py",
    '        for model in MODEL_COST\n        if MODEL_METADATA[model].provider == "ollama"\n    ]\n)',
    '        for model in MODEL_COST\n        if MODEL_METADATA[model].provider == "ollama"\n    ]\n'
    "    # Magpie gateway models — free (local gateway)\n"
    "    + [\n"
    "        BlockCost(\n"
    "            cost_type=BlockCostType.RUN,\n"
    "            cost_amount=0,\n"
    '            cost_filter={"model": model},\n'
    "        )\n"
    "        for model in MODEL_COST\n"
    '        if MODEL_METADATA[model].provider == "magpie"\n'
    "    ]\n"
    ")",
)

print("[DONE] all patches applied")
