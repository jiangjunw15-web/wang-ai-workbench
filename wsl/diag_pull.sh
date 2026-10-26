#!/bin/bash
echo "== containerd env proxy =="
CP=$(pidof containerd | awk '{print $1}')
tr '\0' '\n' < /proc/$CP/environ 2>/dev/null | grep -i proxy || echo "NO PROXY ENV"
echo "== docker info proxy =="
docker info 2>/dev/null | grep -iA1 "http proxy" || echo none
echo "== alpine pull test =="
timeout 90 docker pull alpine:3.20 > /tmp/alpine.log 2>&1 && echo ALPINE_OK || { echo ALPINE_FAIL; tail -5 /tmp/alpine.log; }
echo "== manifest check via proxy =="
TOKEN=$(timeout 30 curl -s -x http://127.0.0.1:17897 "https://auth.docker.io/token?service=registry.docker.io&scope=repository:significantgravitas/autogpt:pull" | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])" 2>/dev/null)
if [ -n "$TOKEN" ]; then
  timeout 30 curl -s -x http://127.0.0.1:17897 -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.index.v1+json" -o /tmp/manifest.json -w "manifest HTTP: %{http_code}\n" "https://registry-1.docker.io/v2/significantgravitas/autogpt/manifests/latest"
  head -c 300 /tmp/manifest.json; echo
else
  echo "TOKEN_FAIL"
fi
echo "== recent containerd/docker logs =="
journalctl -u containerd --since "3 minutes ago" --no-pager 2>/dev/null | grep -iE "error|fail|proxy" | tail -5
journalctl -u docker --since "3 minutes ago" --no-pager 2>/dev/null | grep -iE "error|fail" | tail -5
