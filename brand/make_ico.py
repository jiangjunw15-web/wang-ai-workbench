#!/usr/bin/env python3
"""Generate the 王将军 multi-resolution Windows .ico from the brand SVG shape.

Renders the same mark used by the web app (ice-blue rounded plate, cream
helmet, gold crest, 王 glyph) at 16/32/48/64/128/256 px and packs them
into a single .ico for the window, taskbar, tray and installer.
"""
import struct
import zlib
from pathlib import Path


def png_bytes(size: int) -> bytes:
    """Render the mark at `size` px as a PNG."""
    rows = []
    for y in range(size):
        row = bytearray(b"\x00")
        for x in range(size):
            r, g, b, a = pixel(x, y, size)
            row += bytes((r, g, b, a))
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(tag: bytes, data: bytes) -> bytes:
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def pixel(x: int, y: int, size: int):
    s = size
    fx, fy = x / s, y / s

    # rounded plate with vertical ice-blue gradient
    r0 = 0.22
    cx = min(max(fx, r0), 1 - r0)
    cy = min(max(fy, r0), 1 - r0)
    if (fx - cx) ** 2 + (fy - cy) ** 2 > r0 * r0:
        return (0, 0, 0, 0)
    t = fy
    top = (56, 189, 248)
    bot = (30, 58, 95)
    bg = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))

    cream = (240, 249, 255)
    gold = (251, 191, 36)
    ink = (15, 23, 42)

    # helmet dome
    hx = (fx - 0.5) / 0.34
    hy = (fy - 0.52) / 0.34
    if hx * hx + hy * hy <= 1.0:
        bg = cream
    # visor
    if 0.40 < fy < 0.56 and abs(fx - 0.5) < 0.27:
        bg = ink
    # crest
    if abs(fx - 0.5) < 0.055 and 0.16 < fy < 0.34:
        bg = gold
    # 王 mark
    if 0.60 < fy < 0.74 and abs(fx - 0.5) < 0.14 and abs(fx - 0.5) > 0.085:
        bg = ink
    return (bg[0], bg[1], bg[2], 255)


def build_ico(path: Path) -> None:
    sizes = [16, 32, 48, 64, 128, 256]
    images = [(s, png_bytes(s)) for s in sizes]
    offset = 6 + 16 * len(images)
    header = struct.pack("<HHH", 0, 1, len(images))
    entries = b""
    data = b""
    for size, img in images:
        entries += struct.pack(
            "<BBBBHHII",
            size if size < 256 else 0,
            size if size < 256 else 0,
            0, 0, 1, 32,
            len(img),
            offset + len(data),
        )
        data += img
    path.write_bytes(header + entries + data)
    print("wrote", path, path.stat().st_size, "bytes")


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1:
        out = Path(sys.argv[1])
    else:
        # Default: repo-relative path so the tool works from any checkout.
        out = Path(__file__).resolve().parents[1] / "desktop" / "WangDesktop" / "Assets" / "wang.ico"
    out.parent.mkdir(parents=True, exist_ok=True)
    build_ico(out)
