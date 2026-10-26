#!/bin/bash
# Print the login email and password from the local credential file,
# in a form the browser automation can consume without echoing secrets.
set -euo pipefail
. /root/autogpt_account.env
printf 'EMAIL=%s\n' "$EMAIL"
printf 'PASS=%s\n' "$PASS"
