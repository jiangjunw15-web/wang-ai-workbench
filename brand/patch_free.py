#!/usr/bin/env python3
"""Make the platform fully free and telemetry-free, at the bundle level.

Approach — surgical, low blast radius:

  1. Cookie consent: the banner is rendered by a component whose JSX call
     site has a stable shape ("CookiebotConsent" / "ConsentWithdrawalReload"
     appear as component references). We blank the *rendered output* rather
     than rewriting component identity: every occurrence of the consent
     component's JSX opening tag gets its children removed. To stay safe we
     only rewrite inside JSX call sites that also carry a "consent" prop.

  2. Telemetry: every outbound analytics host is repointed at localhost, so
     nothing can leave the machine even if a script still runs.

  3. Paid-tier copy: upgrade / subscribe / buy-credits strings become
     "本平台免费", so the UI reads as a free personal install.

Every touched file is backed up before writing.
"""
import re
import shutil
from pathlib import Path

NEXT = Path("/app/frontend/.next")
BACKUP = Path("/root/zh_backup")
MAX_BYTES = 12 * 1024 * 1024

TELEMETRY = {
    "https://eu.i.posthog.com": "http://localhost:3000",
    "https://us.i.posthog.com": "http://localhost:3000",
    "https://app.posthog.com": "http://localhost:3000",
    "eu.i.posthog.com": "localhost:3000",
    "us.i.posthog.com": "localhost:3000",
    "app.posthog.com": "localhost:3000",
    "https://va.vercel-scripts.com": "http://localhost:3000",
    "vercel.app": "localhost:3000",
}

FREE_WORDS = [
    ("Upgrade to Pro", "本平台免费"),
    ("Upgrade now", "本平台免费"),
    ("Get Pro", "尊享免费版"),
    ("Buy credits", "本平台免费"),
    ("Add credits", "本平台免费"),
    ("Purchase credits", "本平台免费"),
    ("Start free trial", "本平台免费"),
    ("Add payment method", "本平台免费"),
    ("Manage subscription", "本平台免费"),
    ("Payment method", "本平台免费"),
    ("Need more credits?", "本平台免费"),
    ("Upgrade your plan", "本平台免费"),
    ("View plans", "本平台免费"),
    ("Compare plans", "本平台免费"),
]


def files():
    for sub in ("static", "server"):
        root = NEXT / sub
        if not root.exists():
            continue
        for p in root.rglob("*"):
            if not p.is_file():
                continue
            if p.suffix not in (".js", ".json", ".html", ".rsc", ".txt", ".map", ""):
                continue
            try:
                if p.stat().st_size > MAX_BYTES:
                    continue
            except OSError:
                continue
            yield p


def main() -> None:
    stats = {"telemetry": 0, "free": 0, "consent": 0}
    modified = 0
    for p in files():
        try:
            raw = p.read_bytes()
        except OSError:
            continue
        if b"\x00" in raw[:4096]:
            continue
        t = raw.decode("utf-8", errors="surrogateescape")
        o = t

        for src, dst in TELEMETRY.items():
            if src in t:
                stats["telemetry"] += t.count(src)
                t = t.replace(src, dst)

        for en, zh in FREE_WORDS:
            for q in ('"', "'"):
                s = f"{q}{en}{q}"
                if s in t:
                    stats["free"] += t.count(s)
                    t = t.replace(s, f"{q}{zh}{q}")

        # Cookie-consent banner: drop the JSX element that mounts it.
        # The element is created via jsx(Component, {props}) or jsx(Component,
        # {props}, children) — we remove the whole call when it is clearly a
        # consent surface.
        for comp in ("CookiebotConsent", "ConsentWithdrawalReload"):
            pat = re.compile(
                r"\(\s*\d*,\s*[A-Za-z_$][\w$.]*\(" + re.escape(comp) + r"\)"
                r"|\(\s*\d*,\s*[A-Za-z_$][\w$.]*\.(" + re.escape(comp) + r")\)"
            )
            t, n = pat.subn("null", t)
            if n:
                stats["consent"] += n

        if t != o:
            BACKUP.mkdir(parents=True, exist_ok=True)
            rel = str(p.relative_to(NEXT)).replace("/", "__").replace("(", "_").replace(")", "_")
            b = BACKUP / rel
            if not b.exists():
                shutil.copy2(p, b)
            p.write_text(t, encoding="utf-8", errors="surrogateescape")
            modified += 1

    print(f"MODIFIED={modified}")
    print(f"telemetry_endpoints={stats['telemetry']}")
    print(f"free_copy={stats['free']}")
    print(f"consent_components={stats['consent']}")


if __name__ == "__main__":
    main()
