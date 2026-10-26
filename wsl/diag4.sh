#!/bin/bash
echo "== dockerd proxy env =="
DP=$(pidof dockerd | awk '{print $1}')
tr '\0' '\n' < /proc/$DP/environ 2>/dev/null | grep -i proxy || echo NO_ENV
echo "== last docker daemon errors =="
journalctl -u docker --since "8 minutes ago" --no-pager 2>/dev/null | grep -iE "error|failed" | tail -4
echo "== reliability test: 5x token fetch via proxy =="
for i in 1 2 3 4 5; do
  timeout 25 curl -s -x http://127.0.0.1:17897 -o /dev/null -w "%{http_code} %{time_total}s\n" "https://auth.docker.io/token?service=registry.docker.io&scope=repository:alpine:pull" || echo TIMEOUT
done
echo "== 1ms mirror manifest =="
timeout 20 curl -s -o /dev/null -w "1ms_manifest: %{http_code}\n" "https://docker.1ms.run/v2/significantgravitas/autogpt/manifests/latest" -H "Accept: application/vnd.oci.image.index.v1+json"
timeout 20 curl -s -D - -o /dev/null "https://docker.1ms.run/v2/significantgravitas/autogpt/manifests/latest" -H "Accept: application/vnd.oci.image.index.v1+json" 2>/dev/null | grep -i "www-authenticate" | head -1
