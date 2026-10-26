#!/usr/bin/env python3
"""Route /wang/* on the platform's nginx to the local 王将军 console service.

The service runs on the Windows host (127.0.0.1:8790); nginx in the
container reaches it through the host gateway (172.17.0.1:8790).
"""
import sys
from pathlib import Path

CONF = Path("/opt/autogpt/single-container/nginx/nginx.conf")
MARK = "wang-console"

text = CONF.read_text(encoding="utf-8")
# Replace an existing block (idempotent), otherwise insert before "location / {".
old_port = "proxy_pass http://172.17.0.1:8790;"
new_port = "proxy_pass http://172.17.0.1:18790;"
if old_port in text:
    CONF.write_text(text.replace(old_port, new_port), encoding="utf-8")
    print("REPLACED_PORT")
    sys.exit(0)
if MARK in text:
    print("ALREADY_PATCHED")
    sys.exit(0)

anchor = "        location / {"
if anchor not in text:
    print("ERROR: anchor not found")
    sys.exit(1)

lines = [
    "        # wang-console: 王将军AI工作台 自有控制台",
    "        location /wang/ {",
    "            proxy_pass http://172.17.0.1:18790;",
    "            proxy_http_version 1.1;",
    '            proxy_set_header Host $autogpt_public_host;',
    '            proxy_set_header X-Forwarded-For $remote_addr;',
    '            proxy_set_header X-Forwarded-Proto $autogpt_public_scheme;',
    "            proxy_read_timeout 90s;",
    "            proxy_buffering off;",
    "        }",
    "",
]
block = "\n".join(lines)
text = text.replace(anchor, block + anchor, 1)
CONF.write_text(text, encoding="utf-8")
print("PATCHED")
