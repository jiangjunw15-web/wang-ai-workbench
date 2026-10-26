#!/usr/bin/env python3
"""Inject 王将军AI工作台's own sidebar groups into the built bundle.

The upstream sidebar renders three groups:
  - MAIN_LINKS (Workflows / Marketplace / Build)
  - workspace links (Team / Files)
  - recent chats

This patch, applied to the minified bundle:
  1. Removes the Marketplace entry from MAIN_LINKS (keeps 工作流 + 搭建).
  2. Appends two 王将军-specific entries after the workspace group:
       - 「AI 排序管理」  -> /wang/ai-order
       - 「Magpie 连接」  -> /wang/magpie
  3. Neutralises payment/upgrade entry points so the platform reads as
     fully free for the owner.

All edits are string-level and reversible via /root/zh_backup.
"""
import re
import shutil
import sys
from pathlib import Path

NEXT = Path("/app/frontend/.next")
BACKUP = Path("/root/zh_backup")
MAX_BYTES = 12 * 1024 * 1024

stats = {"sidebar": 0, "marketplace": 0, "payment": 0}
modified: list[Path] = []


def backup(p: Path) -> None:
    BACKUP.mkdir(parents=True, exist_ok=True)
    rel = str(p.relative_to(NEXT)).replace("/", "__").replace("(", "_").replace(")", "_")
    b = BACKUP / rel
    if not b.exists():
        shutil.copy2(p, b)


def iter_js():
    for sub in ("static", "server"):
        root = NEXT / sub
        if not root.exists():
            continue
        for p in root.rglob("*.js"):
            if p.is_file() and p.stat().st_size <= MAX_BYTES:
                yield p


# --- 1) remove Marketplace from the sidebar link list -----------------------
# Minified form (verified in the bundle):
#   [{name:"工作流",href:"/library",icon:u.vtc7},{name:"市场",href:"/marketplace",icon:u.IJjw},{name:"搭建",href:"/build",icon:u.eYXo}]
# Icon refs are member expressions like `u.vtc7`; match any of them.
MP_ENTRY = re.compile(
    r'\{name:"[^"]*",href:"/marketplace",icon:[A-Za-z_$][\w$.]*\},?'
)


def strip_marketplace(text: str) -> str:
    global stats
    new, n = MP_ENTRY.subn("", text)
    if n:
        stats["marketplace"] += n
    return new


# --- 2) inject the two owner links -----------------------------------------
# Workspace list in the bundle:
#   tV=[{name:"文件",href:"/artifacts",icon:u.lBc0}]
# We append our two entries inside that same array literal.
WS_ANCHOR = re.compile(
    r'(\[\{name:"[^"]*",href:"/artifacts",icon:[A-Za-z_$][\w$.]*\})'
)
# Reuse the Files entry's own icon module so no new identifier is needed:
# we cannot know its name statically, so we clone the whole entry and only
# swap name/href. That keeps the icon reference valid.
WANG_TMPL = (
    ',{{name:"AI 排序管理",href:"/wang/ai-order",icon:{icon}}}'
    ',{{name:"Magpie 连接",href:"/wang/magpie",icon:{icon}}}'
)


def inject_wang_links(text: str) -> str:
    global stats
    if "/wang/ai-order" in text:
        return text
    m = WS_ANCHOR.search(text)
    if m:
        # Capture the icon member expression from the Files entry and reuse it.
        icon_m = re.search(r'icon:([A-Za-z_$][\w$.]*)', m.group(1))
        icon = icon_m.group(1) if icon_m else "null"
        add = WANG_TMPL.format(icon=icon)
        # Insert right after the matched Files entry object.
        start = m.end(1)
        text = text[:start] + add + text[start:]
        stats["sidebar"] += 1
    return text


# --- 3) payment / upgrade surfaces -----------------------------------------
PAYMENT_WORDS = [
    ("Upgrade to Pro", "已是尊享版"),
    ("Upgrade now", "已是尊享版"),
    ("Get Pro", "已是尊享版"),
    ("Buy credits", "本平台免费"),
    ("Purchase credits", "本平台免费"),
    ("Subscribe now", "本平台免费"),
    ("Start free trial", "本平台免费"),
    ("Add payment method", "本平台免费"),
]


def neutralise_payments(text: str) -> str:
    global stats
    for en, zh in PAYMENT_WORDS:
        for q in ('"', "'"):
            src = f"{q}{en}{q}"
            if src in text:
                c = text.count(src)
                text = text.replace(src, f"{q}{zh}{q}")
                stats["payment"] += c
    return text


def main() -> None:
    for p in iter_js():
        try:
            raw = p.read_bytes()
        except OSError:
            continue
        if b"\x00" in raw[:4096]:
            continue
        text = raw.decode("utf-8", errors="surrogateescape")
        orig = text
        text = strip_marketplace(text)
        text = inject_wang_links(text)
        text = neutralise_payments(text)
        if text != orig:
            backup(p)
            p.write_text(text, encoding="utf-8", errors="surrogateescape")
            modified.append(p)

    print(f"MODIFIED={len(modified)}")
    print(f"marketplace_removed={stats['marketplace']}")
    print(f"wang_links_injected={stats['sidebar']}")
    print(f"payment_neutralised={stats['payment']}")
    if stats["sidebar"] == 0:
        print("WARNING: sidebar anchor not found — links not injected")


if __name__ == "__main__":
    main()
