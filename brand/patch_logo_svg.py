#!/usr/bin/env python3
"""Swap the inline AutoGPT wordmark SVG for the 王将军 logo image.

The platform renders its brand as an inline <svg> component
(viewBox "0 0 89 40", aria-label "AutoGPT Logo"). We replace the whole
svg element with an <img> pointing at /wang-logo.svg, preserving the
caller's prop spread so width/class behaviour is unchanged.
"""
import re
import shutil
from pathlib import Path

CHUNKS = Path("/app/frontend/.next/static/chunks")
BACKUP = Path("/root/zh_backup")

ARIA = '"aria-label":"AutoGPT Logo"'
IMG = ('(0,{alias}.jsx)("img",{{src:"/wang-logo.svg",alt:"王将军AI工作台",'
       'width:89,height:40,style:{{maxWidth:"100%",height:"auto"}},...{spread}}})')


def match_call(text: str, start: int) -> int:
    """Return index just past the ')' that closes the call opened before `start`."""
    depth = 0
    i = start
    while i < len(text):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return -1


def patch_file(path: Path) -> int:
    text = path.read_text(encoding="utf-8", errors="surrogateescape")
    hits = 0
    out = []
    pos = 0
    while True:
        idx = text.find(ARIA, pos)
        if idx == -1:
            out.append(text[pos:])
            break

        # The svg element: `(0,alias.jsxs)("svg",{ ... ,children:[...]})`
        svg_marker = '("svg",{'
        svg_at = text.rfind(svg_marker, 0, idx)
        if svg_at == -1:
            out.append(text[pos:idx + len(ARIA)])
            pos = idx + len(ARIA)
            continue

        # Find the jsx alias: `(0,alias.jsxs)(` right before "svg"
        alias_m = re.search(r"\((\d+),(\w+)\.jsx[s]?\)", text[max(0, svg_at - 40):svg_at + 10])
        if not alias_m:
            out.append(text[pos:idx + len(ARIA)])
            pos = idx + len(ARIA)
            continue
        alias = alias_m.group(2)

        # The prop spread inside the svg props (e.g. ...e / ...a / ...s)
        props_region = text[svg_at:idx]
        spread_m = re.search(r"\.\.\.(\w+)", props_region)
        spread = spread_m.group(1) if spread_m else ""

        # Opening paren of the whole jsx call
        call_open = text.rfind("(0,", 0, svg_at)
        call_end = match_call(text, call_open)
        if call_end == -1:
            out.append(text[pos:idx + len(ARIA)])
            pos = idx + len(ARIA)
            continue

        replacement = IMG.format(alias=alias, spread=spread)
        out.append(text[pos:call_open])
        out.append(replacement)
        pos = call_end
        hits += 1

    if hits:
        BACKUP.mkdir(parents=True, exist_ok=True)
        b = BACKUP / path.name
        if not b.exists():
            shutil.copy2(path, b)
        path.write_text("".join(out), encoding="utf-8", errors="surrogateescape")
    return hits


def main() -> None:
    total = 0
    files = 0
    for f in CHUNKS.rglob("*.js"):
        try:
            t = f.read_text(encoding="utf-8", errors="surrogateescape")
        except OSError:
            continue
        if ARIA not in t:
            continue
        n = patch_file(f)
        if n:
            total += n
            files += 1
            print(f"patched {f.name}: {n} logo component(s)")
    print(f"files={files} components={total}")
    if total == 0:
        print("WARNING: nothing replaced")


if __name__ == "__main__":
    main()
