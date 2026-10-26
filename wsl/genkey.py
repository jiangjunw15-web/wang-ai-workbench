import json
import sys

sys.path.insert(0, "/app/autogpt_platform/autogpt_libs")

from autogpt_libs.api_key.keysmith import APIKeySmith

k = APIKeySmith().generate_key()
print(
    json.dumps(
        {
            "key": k.key,
            "head": k.head,
            "tail": k.tail,
            "hash": k.hash,
            "salt": k.salt,
        }
    )
)
