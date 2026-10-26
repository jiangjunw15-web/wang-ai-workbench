#!/usr/bin/env python3
"""Dump the exact source around the AutoGPTLogo component for inspection."""
import re
from pathlib import Path

CHUNKS = Path("/app/frontend/.next/static/chunks")
for f in CHUNKS.rglob("*.js"):
    t = f.read_text(encoding="utf-8", errors="surrogateescape")
    for m in re.finditer(r'"AutoGPT Logo"', t):
        s = max(0, m.start() - 260)
        print("=== ", f.name, " @", m.start())
        print(t[s:m.start() + 700])
        print()
