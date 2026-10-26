#!/usr/bin/env python3
"""Localize the AutoGPT Platform frontend bundle in place (v2).

Covers the quoting styles actually present in a minified Next.js bundle:
  1. "en"        (string literal)
  2. 'en'        (single-quoted literal)
  3. `en`        (template literal)
  4. ["en"]      (array literal member, no surrounding quotes beyond above)
  5. Bare identifiers are NEVER touched (avoids breaking code).

Every modified file is backed up under /root/zh_backup/ (reversible).
A report of applied replacements goes to /root/zh_patch_report.txt.
"""
import json
import shutil
import sys
from pathlib import Path

ROOTS = [
    Path("/app/frontend/.next/static"),
    Path("/app/frontend/.next/server"),
]
DICT = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
BACKUP = Path("/root/zh_backup")
MAX_BYTES = 12 * 1024 * 1024

PAIRS: list[tuple[str, str]] = []
for group in DICT.values():
    for en, zh in group.items():
        if en and en != zh:
            PAIRS.append((en, zh))
PAIRS.sort(key=lambda kv: -len(kv[0]))

# Words that are too generic/dangerous to replace blind: they commonly appear
# as object keys, CSS class names, or code identifiers in a minified bundle.
# Only SHORT single words (<=6 chars, no space) are filtered — longer phrases
# like "Save changes" are safe because they read as prose.
SHORT_WORD_BLOCKLIST = {
    "View", "Chat", "Chats", "Ctrl", "Avg", "Note", "Step", "Type", "Model",
    "Tools", "Task", "Tasks", "File", "Files", "Filter", "filter", "Actions",
    "Results", "Logs", "Usage", "Agent", "Agents", "Blocks", "Prompt",
    "Template", "History", "Version", "Author", "Owner", "Role", "Team",
    "Details", "Summary", "Title", "Name", "Email", "Password", "Date",
    "Time", "User", "Users", "All", "Yes", "No", "Add", "Remove", "Open",
    "Close", "Back", "Next", "Submit", "Copy", "Save", "Cancel", "Delete",
    "Edit", "Create", "New", "Search", "Error", "Success", "Warning", "Failed",
    "Pending", "Active", "Paused", "Draft", "Loading", "Retry", "Refresh",
    "Apply", "Reset", "Share", "Export", "Import", "Send", "Run", "Stop",
    "Start", "Home", "Build", "Idle", "Status", "Model", "Input", "Output",
    "Custom", "Default", "Required", "Optional", "Advanced", "General",
    "Workflow", "Schedule", "Execution", "Dashboard", "Activity", "Message",
    "Sign out", "Sign in",
}
PAIRS = [
    (en, zh)
    for en, zh in PAIRS
    if not (en in SHORT_WORD_BLOCKLIST and len(en) <= 6 and " " not in en)
]


def esc(s: str) -> str:
    return "".join(ch if ord(ch) < 128 else f"\\u{ord(ch):04x}" for ch in s)


def build_variants(en: str, zh: str) -> list[tuple[str, str]]:
    """Source -> target snippets across quoting styles (longest-match first)."""
    out = []
    for q in ('"', "'", "`"):
        out.append((f"{q}{en}{q}", f"{q}{zh}{q}"))
        if any(ord(c) > 127 for c in zh):
            out.append((f"{q}{en}{q}", f"{q}{esc(zh)}{q}"))
    return out


def patch_text(text: str) -> tuple[str, dict[str, int]]:
    stats: dict[str, int] = {}
    for en, zh in PAIRS:
        n = 0
        for src, dst in build_variants(en, zh):
            if src in text:
                c = text.count(src)
                text = text.replace(src, dst)
                n += c
        if n:
            stats[en] = stats.get(en, 0) + n
    return text, stats


def iter_files():
    for root in ROOTS:
        if not root.exists():
            continue
        for p in root.rglob("*"):
            if not p.is_file():
                continue
            # Accept every plausible text asset; the null-byte check below
            # filters out binaries.
            if p.suffix not in (".js", ".json", ".css", ".html", ".rsc", ".txt", ".map", ""):
                continue
            try:
                if p.stat().st_size > MAX_BYTES:
                    continue
            except OSError:
                continue
            yield p


def main() -> None:
    total_stats: dict[str, int] = {}
    modified: list[Path] = []
    scanned = 0

    for path in iter_files():
        scanned += 1
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
            rel = str(path.relative_to("/app/frontend/.next"))
            bpath = BACKUP / rel.replace("/", "__").replace("(", "_").replace(")", "_")
            if not bpath.exists():
                shutil.copy2(path, bpath)
            path.write_text(new_text, encoding="utf-8", errors="surrogateescape")
            modified.append(path)
            for k, v in stats.items():
                total_stats[k] = total_stats.get(k, 0) + v

    lines = ["# zh-CN bundle patch report (v2)", f"scanned={scanned} modified={len(modified)}", ""]
    for en, zh in PAIRS:
        if en in total_stats:
            lines.append(f"{total_stats[en]:5d}  {en}  ->  {zh}")
    Path("/root/zh_patch_report.txt").write_text("\n".join(lines), encoding="utf-8")

    print(f"SCANNED={scanned} MODIFIED={len(modified)} REPLACEMENTS={sum(total_stats.values())}")
    for en in list(total_stats)[:12]:
        print(f"  {total_stats[en]}x {en}")
    if not total_stats:
        print("WARNING: nothing replaced")


if __name__ == "__main__":
    main()
