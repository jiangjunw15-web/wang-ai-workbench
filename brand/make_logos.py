#!/usr/bin/env python3
"""Render the 王将军 logo SVG into the PNG files the platform references.

The bundle references /autogpt-logo-light-bg.png and /autogpt-logo-dark-bg.png.
We replace their bytes with a rendered PNG of the 王将军 mark so the sidebar
and login header show the owner's brand, not AutoGPT's.
"""
import struct
import zlib
from pathlib import Path

PUB = Path("/app/frontend/public")


def png(width: int, height: int, pixels: list[list[tuple[int, int, int, int]]]) -> bytes:
    raw = b""
    for row in pixels:
        raw += b"\x00" + b"".join(bytes(p) for p in row)

    def chunk(tag: bytes, data: bytes) -> bytes:
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def rounded(x: int, y: int, w: int, h: int, r: int) -> bool:
    """Inside a rounded rectangle?"""
    if not (0 <= x < w and 0 <= y < h):
        return False
    cx = min(max(x, r), w - 1 - r)
    cy = min(max(y, r), h - 1 - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def build(size: int, dark: bool) -> bytes:
    # ice-blue gradient background, cream helmet, gold crest
    top = (56, 189, 248)
    bottom = (30, 58, 95)
    cream = (240, 249, 255)
    gold = (251, 191, 36)
    ink = (15, 23, 42)

    S = size
    px = []
    for y in range(S):
        row = []
        t = y / max(1, S - 1)
        bg = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(S):
            # rounded plate
            if not rounded(x, y, S, S, int(S * 0.22)):
                row.append((0, 0, 0, 0))
                continue
            r, g, b = bg
            # helmet dome
            hx = (x - S / 2) / (S * 0.34)
            hy = (y - S * 0.52) / (S * 0.34)
            if hx * hx + hy * hy <= 1.0:
                r, g, b = cream
            # visor band
            if 0.40 * S < y < 0.56 * S and abs(x - S / 2) < S * 0.27:
                r, g, b = ink
            # crest
            if abs(x - S / 2) < S * 0.055 and 0.16 * S < y < 0.34 * S:
                r, g, b = gold
            # 王 mark on the chest
            if 0.60 * S < y < 0.74 * S and abs(x - S / 2) < S * 0.14:
                if abs(x - S / 2) > S * 0.085:
                    r, g, b = ink
            row.append((r, g, b, 255))
        px.append(row)
    return png(S, S, px)


def main() -> None:
    targets = {
        "autogpt-logo-light-bg.png": False,
        "autogpt-logo-dark-bg.png": True,
        "apple-touch-icon.png": False,
        "notification-icon-192.png": False,
        "notification-badge-96.png": False,
    }
    for name, dark in targets.items():
        p = PUB / name
        if not p.exists():
            print("skip (missing):", name)
            continue
        size = 512 if "logo" in name else (180 if "192" in name else 96)
        p.write_bytes(build(size, dark))
        print("wrote", name, size)


if __name__ == "__main__":
    main()
