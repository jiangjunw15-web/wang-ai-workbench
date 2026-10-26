#!/usr/bin/env python3
"""Restore bundle files from /root/zh_backup (undo the logo-component patch).

The backup directory holds the pre-patch copy of every file we touched.
This restores the ones whose current content no longer contains the
AutoGPT logo component (i.e. the ones the last patch damaged).
"""
import shutil
from pathlib import Path

BACKUP = Path("/root/zh_backup")
NEXT = Path("/app/frontend/.next")
ARIA = '"aria-label":"AutoGPT Logo"'

restored = 0
for b in sorted(BACKUP.glob("*")):
    if not b.is_file():
        continue
    # Backup names are the original relative path with '/' -> '__'
    rel = b.name.replace("__", "/")
    target = NEXT / rel
    if not target.exists():
        continue
    try:
        cur = target.read_text(encoding="utf-8", errors="surrogateescape")
    except OSError:
        continue
    if ARIA in cur:
        continue  # still intact, nothing to restore
    # damaged: restore the pre-patch copy
    shutil.copy2(b, target)
    restored += 1
    print("restored", rel)

print("restored files:", restored)
