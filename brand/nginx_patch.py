#!/usr/bin/env python3
"""Insert a /_next/static/ revalidation location into the platform nginx conf."""
import sys
from pathlib import Path

CONF = Path("/opt/autogpt/single-container/nginx/nginx.conf")
MARK = "wang-static-revalidate"

text = CONF.read_text(encoding="utf-8")
if MARK in text:
    print("ALREADY_PATCHED")
    sys.exit(0)

anchor = "        location / {"
if anchor not in text:
    print("ERROR: anchor not found")
    sys.exit(1)

lines = [
    "        # wang-static-revalidate: patched bundles must reach the browser",
    "        location /_next/static/ {",
    "            proxy_pass http://autogpt_frontend;",
    "            proxy_http_version 1.1;",
    '            proxy_set_header Host $autogpt_public_host;',
    "            proxy_hide_header Cache-Control;",
    "            proxy_hide_header ETag;",
    '            add_header Cache-Control "no-cache, must-revalidate" always;',
    "        }",
    "",
]
block = "\n".join(lines)
text = text.replace(anchor, block + anchor, 1)
CONF.write_text(text, encoding="utf-8")
print("PATCHED")
