#!/usr/bin/env python3
"""Cache-bust patched chunks so browsers fetch them instead of reusing a
stale hash-named cache entry.

Only files under `.next/static` are renamed: `.next/server` modules are
resolved by conventional path (e.g. server/app/page.js) and renaming them
breaks Next.js module resolution. All internal references to the renamed
files — including the server-side manifests that point at static assets —
are rewritten.
"""
import re
import sys
from pathlib import Path

NEXT = Path("/app/frontend/.next")
SUFFIX = ".wang1"

MARKERS = ("欢迎回来", "王将军", "wang/ai-order", "工作流简报", "暂无对话", "排序方式")

changed = 0
refs_updated = 0

# 1) candidates — STATIC ONLY (js + css; server keeps conventional paths)
candidates: list[Path] = []
for pat in ("*.js", "*.css"):
    for p in (NEXT / "static").rglob(pat):
        if not p.is_file():
            continue
        try:
            t = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        # CSS files carry the theme markers as raw values.
        css_markers = ("56 189 248", "15 23 42", "248 250 252")
        if pat == "*.css":
            if any(m in t for m in css_markers):
                candidates.append(p)
            continue
        if any(m in t for m in MARKERS):
            candidates.append(p)

print("patched static assets found:", len(candidates))

# 2) rename: name.js -> name.wang1.js
renames: dict[str, str] = {}
for p in candidates:
    if SUFFIX in p.name:
        continue
    new_name = p.stem + SUFFIX + p.suffix
    new_path = p.with_name(new_name)
    if new_path.exists():
        new_path.unlink()
    p.rename(new_path)
    renames[p.name] = new_name
    changed += 1

print("renamed:", changed)

# 3) rewrite references everywhere (static + server)
for sub in ("static", "server"):
    root = NEXT / sub
    if not root.exists():
        continue
    for p in root.rglob("*"):
        if not p.is_file() or p.suffix not in (".js", ".css", ".json", ".html", ".rsc", ".txt", ".map", ""):
            continue
        try:
            t = p.read_text(encoding="utf-8", errors="surrogateescape")
        except OSError:
            continue
        orig = t
        for old, new in renames.items():
            if old in t:
                t = t.replace(old, new)
        if t != orig:
            p.write_text(t, encoding="utf-8", errors="surrogateescape")
            refs_updated += 1

print("files with rewritten refs:", refs_updated)
