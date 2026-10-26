#!/usr/bin/env python3
import sys
from pathlib import Path

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
if 'MAGPIE_GROUP_FREE = "group/free"' in text:
    print("[SKIP] already patched")
    sys.exit(0)
old = "class LLMModel(str, Enum, metaclass=LLMModelMeta):\n"
new = (
    "class LLMModel(str, Enum, metaclass=LLMModelMeta):\n"
    "    # -- Magpie gateway models (added by local setup; see catalog.py) --\n"
    '    MAGPIE_GROUP_FREE = "group/free"\n'
    '    MAGPIE_GROUP_DEEPSEEK = "group/deepseek"\n'
    '    MAGPIE_GROUP_KIMI = "group/kimi"\n'
    '    MAGPIE_GROUP_MICU = "group/micu"\n'
    '    MAGPIE_AUTO_DEEPSEEK_V4_FLASH = "auto/deepseek-v4-flash"\n'
    '    MAGPIE_AUTO_MINIMAX_M31_FLASH = "auto/minimax-m3.1-flash"\n'
    '    MAGPIE_DEEPSEEK_V4_FLASH = "deepseek/deepseek-v4-flash"\n'
)
assert text.count(old) == 1, "anchor not found"
p.write_text(text.replace(old, new), encoding="utf-8")
print("[OK] llm_models.py enum members added")
