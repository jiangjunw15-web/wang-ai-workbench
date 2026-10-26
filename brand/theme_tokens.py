#!/usr/bin/env python3
"""Recompute the 王将军 ice-blue design tokens as real HSL triplets.

The earlier token file stored RGB components where shadcn expects
"HSL H S%" triplets, which produced a brown sidebar. This script derives
the correct HSL from the intended hex colours.
"""
import colorsys
import re
import shutil
from pathlib import Path

CSS_DIR = Path("/app/frontend/.next/static/css")
BACKUP = Path("/root/zh_backup")

# token -> (light hex, dark hex)
PALETTE = {
    "--background": ("#F8FAFC", "#020617"),
    "--foreground": ("#0F172A", "#E2E8F0"),
    "--card": ("#FFFFFF", "#0F172A"),
    "--card-foreground": ("#0F172A", "#E2E8F0"),
    "--popover": ("#FFFFFF", "#0F172A"),
    "--popover-foreground": ("#0F172A", "#E2E8F0"),
    "--primary": ("#1E3A5F", "#38BDF8"),
    "--primary-foreground": ("#F0F9FF", "#084C6D"),
    "--secondary": ("#F1F5F9", "#1E293B"),
    "--secondary-foreground": ("#1E293B", "#E2E8F0"),
    "--muted": ("#F1F5F9", "#1E293B"),
    "--muted-foreground": ("#64748B", "#94A3B8"),
    "--accent": ("#38BDF8", "#0EA5E9"),
    "--accent-foreground": ("#084C6D", "#F0F9FF"),
    "--destructive": ("#EF4444", "#7F1D1D"),
    "--destructive-foreground": ("#FEF2F2", "#FEF2F2"),
    "--border": ("#E2E8F0", "#1E293B"),
    "--input": ("#CBD5E1", "#334155"),
    "--ring": ("#38BDF8", "#38BDF8"),
    "--chart-1": ("#0EA5E9", "#38BDF8"),
    "--chart-2": ("#38BDF8", "#0EA5E9"),
    "--chart-3": ("#1E3A5F", "#7DD3FC"),
    "--chart-4": ("#7DD3FC", "#BAE6FD"),
    "--chart-5": ("#BAE6FD", "#1E3A5F"),
    "--sidebar-background": ("#0F172A", "#020617"),
    "--sidebar-foreground": ("#E2E8F0", "#CBD5E1"),
    "--sidebar-primary": ("#38BDF8", "#38BDF8"),
    "--sidebar-primary-foreground": ("#084C6D", "#084C6D"),
    "--sidebar-accent": ("#1E293B", "#0F172A"),
    "--sidebar-accent-foreground": ("#F0F9FF", "#F0F9FF"),
    "--sidebar-border": ("#1E293B", "#1E293B"),
    "--sidebar-ring": ("#38BDF8", "#38BDF8"),
}


def hex_to_hsl(hexstr: str) -> str:
    h = hexstr.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hh, ll, ss = colorsys.rgb_to_hls(r, g, b)
    return f"{round(hh * 360, 1)} {round(ss * 100, 1)}% {round(ll * 100, 1)}%"


def split_scopes(text: str):
    import re
    m = re.search(r"\.dark\s*\{", text)
    if not m:
        return text, "", len(text)
    start = m.start()
    i = text.index("{", start)
    depth = 0
    end = None
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
        i += 1
    if end is None:
        return text, "", len(text)
    return text[:start], text[start:end], end


def apply(text: str, dark: bool) -> tuple[str, int]:
    import re
    n = 0
    for name, (light, darkv) in PALETTE.items():
        val = hex_to_hsl(darkv if dark else light)
        pat = re.compile(r"(" + re.escape(name) + r"\s*:\s*)([^;}]+)(\s*[;}])")
        text, c = pat.subn(lambda m: m.group(1) + val + m.group(3), text)
        n += c
    return text, n


def main() -> None:
    total = 0
    files = 0
    for f in CSS_DIR.rglob("*.css"):  # matches .css and .wang1.css
        try:
            text = f.read_text(encoding="utf-8", errors="surrogateescape")
        except OSError:
            continue
        if "--sidebar-background" not in text:
            continue
        orig = text
        light, dark, de = split_scopes(text)
        light, n1 = apply(light, dark=False)
        dark, n2 = apply(dark, dark=True)
        text = light + dark + text[de:]
        if text != orig:
            BACKUP.mkdir(parents=True, exist_ok=True)
            b = BACKUP / f.name
            if not b.exists():
                shutil.copy2(f, b)
            f.write_text(text, encoding="utf-8", errors="surrogateescape")
            files += 1
            total += n1 + n2
    print(f"css_files={files} tokens={total}")
    print("sample:", "--sidebar-background light =", hex_to_hsl(PALETTE["--sidebar-background"][0]),
          "| dark =", hex_to_hsl(PALETTE["--sidebar-background"][1]))


if __name__ == "__main__":
    main()
