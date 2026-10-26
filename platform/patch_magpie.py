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
            base_url=os.getenv("MAGPIE_BASE_URL", "http://127.0.0.1:3425/v1"),
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

# ---- 4) catalog.py: provider + creators + models (driven by a models file) ----
# The model list is NOT hardcoded: it is read from a JSON file so any gateway's
# models can be registered. Provide it via the MODELS_JSON env var or a
# `magpie-models.json` next to this script. Format:
#   [ {"slug": "...", "display_name": "...", "creator": "...",
#      "context_window": 1048576, "max_output_tokens": 524288}, ... ]
import json
import os


def _load_models() -> list:
    path = os.environ.get("MODELS_JSON")
    if not path:
        here = Path(__file__).resolve().parent / "magpie-models.json"
        path = str(here) if here.exists() else ""
    if not path or not Path(path).exists():
        return []
    with open(path, encoding="utf-8") as f:
        return json.load(f)


MODELS = _load_models()

patch(
    "catalog.py",
    '            CatalogProvider(name="openai", display_name="OpenAI"),\n',
    '            CatalogProvider(name="openai", display_name="OpenAI"),\n'
    '            CatalogProvider(name="magpie", display_name="OpenAI-compatible gateway"),\n',
)

# creators: derive from the models file so no vendor names are hardcoded.
creators = sorted({m.get("creator", "gateway") for m in MODELS})
creator_block = "".join(
    f'            CatalogCreator(name="{c}", display_name="{c}"),\n' for c in creators
)
if creator_block:
    patch(
        "catalog.py",
        '            CatalogCreator(name="xiaomi", display_name="Xiaomi"),\n',
        '            CatalogCreator(name="xiaomi", display_name="Xiaomi"),\n' + creator_block,
    )


def _catalog_model(m: dict) -> str:
    cw = m.get("context_window", 1048576)
    mot = m.get("max_output_tokens")
    mot_line = f"                max_output_tokens={mot},\n" if mot else ""
    return (
        "            CatalogModel(\n"
        f'                slug="{m["slug"]}",\n'
        f'                display_name="{m.get("display_name", m["slug"])}",\n'
        '                provider="magpie",\n'
        f'                creator="{m.get("creator", "gateway")}",\n'
        f"                context_window={cw},\n"
        f"{mot_line}"
        "                price_tier=1,\n"
        "                cost=CatalogModelCost(run_credits=1),\n"
        "            ),\n"
    )


MAGPIE_MODELS = "".join(_catalog_model(m) for m in MODELS)

if MAGPIE_MODELS:
    text = (D / "catalog.py").read_text(encoding="utf-8")
    anchor = "\n        ],\n    )\n"
    idx = text.rfind(anchor)
    if idx == -1:
        raise SystemExit("[FAIL] catalog.py: models-list closing anchor not found")
    text = text[:idx] + "\n" + MAGPIE_MODELS + text[idx:]
    (D / "catalog.py").write_text(text, encoding="utf-8")
    print(f"[OK] catalog.py: {len(MODELS)} gateway models inserted")
else:
    print("[WARN] no models file found; catalog models not inserted "
          "(set MODELS_JSON or add magpie-models.json)")

# ---- 5) llm_models.py: enum members generated from the same models list ----
def _enum_name(slug: str) -> str:
    return "MAGPIE_" + "".join(
        ch if ch.isalnum() else "_" for ch in slug.upper()
    ).replace("__", "_")


enum_block = "".join(
    f'    {_enum_name(m["slug"])} = "{m["slug"]}"\n' for m in MODELS
)
if enum_block:
    patch(
        "llm_models.py",
        "class LLMModel(str, Enum, metaclass=LLMModelMeta):\n",
        "class LLMModel(str, Enum, metaclass=LLMModelMeta):\n"
        "    # -- gateway models (added by setup; see catalog.py) --\n" + enum_block,
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
