#!/usr/bin/env python3
"""Undo the chunk renaming: strip the .wang1 suffix back to the original name.

server/ entry modules are resolved by conventional path, so they must keep
their original names. This restores both the filenames and the references.
"""
from pathlib import Path

NEXT = Path("/app/frontend/.next")
SUFFIX = ".wang1"

# 1) restore filenames
restored = 0
renames: dict[str, str] = {}
for sub in ("static", "server"):
    root = NEXT / sub
    if not root.exists():
        continue
    for ext in ("js", "css"):
        for p in root.rglob(f"*{SUFFIX}.{ext}"):
            orig_name = p.name.replace(f"{SUFFIX}.{ext}", f".{ext}")
            target = p.with_name(orig_name)
            if target.exists():
                target.unlink()
            p.rename(target)
            renames[p.name] = orig_name
            restored += 1

print("restored files:", restored)

# 2) rewrite references back
updated = 0
for sub in ("static", "server"):
    root = NEXT / sub
    if not root.exists():
        continue
    for p in root.rglob("*"):
        if not p.is_file() or p.suffix not in (".js", ".json", ".html", ".rsc", ".txt", ".map", ""):
            continue
        try:
            t = p.read_text(encoding="utf-8", errors="surrogateescape")
        except OSError:
            continue
        o = t
        for old, new in renames.items():
            if old in t:
                t = t.replace(old, new)
        if t != o:
            p.write_text(t, encoding="utf-8", errors="surrogateescape")
            updated += 1

print("ref files fixed:", updated)
