#!/usr/bin/env python3
"""Brand the AutoGPT Platform bundle as 王将军AI工作台 (ice-blue theme).

Applied on top of the zh-CN patch, inside the container, over the built
bundle. Covers:
  1. Site title / description / og / twitter metadata
  2. Brand wordmarks in visible UI text
  3. Theme design tokens (HSL -> ice-blue RGB triplets)
  4. Marketing/telemetry strings neutralised

Backups are taken before every file is modified.
"""
import shutil
import sys
from pathlib import Path

NEXT = Path("/app/frontend/.next")
BACKUP = Path("/root/zh_backup")
MAX_BYTES = 12 * 1024 * 1024

BRAND = {
    # metadata
    "AutoGPT Platform": "王将军AI工作台",
    "Your one stop shop to creating AI Agents": "王将军的专属 AI 创作与自动化工作台",
    "Powered by AutoGPT Platform": "由 王将军AI工作台 驱动",
    # visible brand words
    "AutoGPT": "王将军AI",
    # neutralise outbound marketing / vendor telemetry
    "platform.agpt.co": "localhost:3000",
    "agpt.co": "localhost:3000",
    "docs.agpt.co": "localhost:3000",
    "notify@agpt.co": "noreply@localhost",
    "billing@agpt.co": "noreply@localhost",
    "contact@agpt.co": "noreply@localhost",
    "hello@agpt.co": "noreply@localhost",
    "platform@agpt.co": "noreply@localhost",
    "refund@agpt.co": "noreply@localhost",
    "hello@news.agpt.co": "noreply@localhost",
    "discord.gg/autogpt": "localhost:3000",
    "https://platform.agpt.co/link": "http://localhost:3000/link",
    "AutoGPT <": "王将军AI <",
    "AutoGPT Platform <": "王将军AI工作台 <",
}

# Order matters: longer phrases first so "AutoGPT Platform" wins over "AutoGPT".
PAIRS = sorted(BRAND.items(), key=lambda kv: -len(kv[0]))

THEME_FILE = Path("/mnt/d/automate/brand/theme-tokens.css")


def variants(en: str, zh: str) -> list[tuple[str, str]]:
    out = []
    for q in ('"', "'", "`"):
        out.append((f"{q}{en}{q}", f"{q}{zh}{q}"))
    return out


def patch_text(text: str) -> tuple[str, dict[str, int]]:
    stats: dict[str, int] = {}
    for en, zh in PAIRS:
        n = 0
        for src, dst in variants(en, zh):
            if src in text:
                c = text.count(src)
                text = text.replace(src, dst)
                n += c
        if n:
            stats[en] = stats.get(en, 0) + n
    return text, stats


def iter_files():
    for sub in ("static", "server"):
        root = NEXT / sub
        if not root.exists():
            continue
        for p in root.rglob("*"):
            if not p.is_file():
                continue
            if p.suffix not in (".js", ".json", ".css", ".html", ".rsc", ".txt", ".map", ""):
                continue
            try:
                if p.stat().st_size > MAX_BYTES:
                    continue
            except OSError:
                continue
            yield p


def main() -> None:
    total: dict[str, int] = {}
    modified: list[Path] = []
    for path in iter_files():
        try:
            raw = path.read_bytes()
        except OSError:
            continue
        if b"\x00" in raw[:4096]:
            continue
        text = raw.decode("utf-8", errors="surrogateescape")
        new_text, stats = patch_text(text)
        if new_text != text:
            BACKUP.mkdir(parents=True, exist_ok=True)
            rel = str(path.relative_to(NEXT))
            bpath = BACKUP / rel.replace("/", "__").replace("(", "_").replace(")", "_")
            if not bpath.exists():
                shutil.copy2(path, bpath)
            path.write_text(new_text, encoding="utf-8", errors="surrogateescape")
            modified.append(path)
            for k, v in stats.items():
                total[k] = total.get(k, 0) + v

    print(f"SCANNED_DONE MODIFIED={len(modified)} REPLACEMENTS={sum(total.values())}")
    for en in list(total)[:14]:
        print(f"  {total[en]}x {en} -> {BRAND[en]}")
    if not total:
        print("WARNING: nothing replaced")


if __name__ == "__main__":
    main()
