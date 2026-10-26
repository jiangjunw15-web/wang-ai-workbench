#!/usr/bin/env python3
"""Insert magpie models into catalog.py by bracket-matching the models=[...] list."""
import sys
from pathlib import Path

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
if "group/free" in text:
    print("[SKIP] already patched")
    sys.exit(0)

marker = "models=["
mi = text.index(marker)
i = mi + len(marker) - 1  # position of '['
depth = 0
end = None
in_str = None
esc = False
while i < len(text):
    c = text[i]
    if in_str:
        if esc:
            esc = False
        elif c == "\\":
            esc = True
        elif c == in_str:
            in_str = None
    elif c == "#":
        while i < len(text) and text[i] != "\n":
            i += 1
        continue
    else:
        if c in "\"'":
            in_str = c
        elif c == "[":
            depth += 1
        elif c == "]":
            depth -= 1
            if depth == 0:
                end = i
                break
    i += 1
if end is None:
    raise SystemExit("[FAIL] models list close not found")

MAGPIE_MODELS = '''
            # ----- Magpie Gateway (local) -----
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

text = text[:end] + MAGPIE_MODELS + "            " + text[end:]
p.write_text(text, encoding="utf-8")
print("[OK] magpie models inserted via bracket match")
