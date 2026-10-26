import asyncio
import os
import sys

# Inherit the fully-resolved environment from PID 1 (supervisord), which
# received the generated runtime config; `docker exec` does not get it.
with open("/proc/1/environ", "rb") as f:
    for item in f.read().split(b"\0"):
        if b"=" in item:
            k, _, v = item.partition(b"=")
            os.environ.setdefault(k.decode(errors="replace"), v.decode(errors="replace"))

# Also keep the raw runtime env file as a fallback source.
try:
    for line in open("/data/config/runtime.env"):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, _, v = line.partition("=")
            os.environ.setdefault(k.strip(), v.strip().strip('"'))
except FileNotFoundError:
    pass

sys.path.insert(0, "/app/autogpt_platform/backend")

from prisma.enums import APIKeyPermission
from backend.data import db as database
from backend.data.auth.api_key import create_api_key


async def main() -> None:
    user_id = sys.argv[1]
    await database.connect()
    try:
        info, plaintext = await create_api_key(
            name="magpie-team-key",
            user_id=user_id,
            permissions=list(APIKeyPermission),
            description="AI team full access key created by local setup",
        )
        print("KEY_ID:", info.id)
        print("API_KEY:", plaintext)
    finally:
        await database.disconnect()


asyncio.run(main())
