#!/usr/bin/env python3
"""Check whether the injected branding script actually ran in the page."""
import json
import urllib.request

# The desktop client injects via AddScriptToExecuteOnDocumentCreatedAsync.
# This probe checks the *server-rendered* HTML for our wordmark reference and
# reports what the login page contains, so we can tell whether the swap is
# a client-side concern or a server-side one.
html = urllib.request.urlopen("http://127.0.0.1:3000/login", timeout=20).read().decode("utf-8", "replace")
print("server html has wang-wordmark:", "wang-wordmark" in html)
print("server html has AutoGPT svg:", 'aria-label="AutoGPT Logo"' in html)
print("wordmark asset reachable:", urllib.request.urlopen(
    "http://127.0.0.1:3000/wang-wordmark.svg", timeout=20).status)
