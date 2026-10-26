#!/usr/bin/env python3
"""Give the 王将军 logo unique filenames so browsers refetch it, and
repoint the bundle references."""
from pathlib import Path

PUB = Path("/app/frontend/public")
NEXT = Path("/app/frontend/.next")

RENAMES = {
    "autogpt-logo-light-bg.png": "wang-logo-light.png",
    "autogpt-logo-dark-bg.png": "wang-logo-dark.png",
}

for old, new in RENAMES.items():
    src = PUB / old
    if src.exists():
        (PUB / new).write_bytes(src.read_bytes())
        print("copied", old, "->", new)
    else:
        print("MISSING source:", old)

n = 0
for p in (NEXT / "static").rglob("*.js"):
    try:
        t = p.read_text(encoding="utf-8", errors="surrogateescape")
    except OSError:
        continue
    o = t
    for old, new in RENAMES.items():
        if old in t:
            t = t.replace(old, new)
    if t != o:
        p.write_text(t, encoding="utf-8", errors="surrogateescape")
        n += 1
print("js rewritten:", n)

# also refresh the favicons in place (same content, new bytes)
for name in ("favicon.ico", "favicon-local.ico"):
    p = PUB / name
    print(name, "exists" if p.exists() else "MISSING")
