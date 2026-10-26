#!/bin/bash
echo "== pull proc =="
ps aux | grep -E "docker pull|1382" | grep -v grep | head -3
echo "== containerd connections =="
CP=$(pidof containerd | awk '{print $1}')
ss -tnp 2>/dev/null | grep "pid=$CP" | head -8
echo "== containerd image fetch logs =="
journalctl -u containerd --since "10 minutes ago" --no-pager 2>/dev/null | grep -iE "fetch|pull|blob|layer" | grep -viE "skip loading|plugin" | tail -8
echo "== test big blob download speed via proxy =="
TOKEN=$(timeout 30 curl -s -x http://127.0.0.1:17897 "https://auth.docker.io/token?service=registry.docker.io&scope=repository:significantgravitas/autogpt:pull" | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])" 2>/dev/null)
AMD_DIGEST=$(python3 -c "
import json
d=json.load(open('/tmp/manifest.json'))
for m in d['manifests']:
    p=m.get('platform',{})
    if p.get('architecture')=='amd64' and p.get('os')=='linux' and 'attestation' not in str(p.get('variant','')):
        print(m['digest']); break
" 2>/dev/null)
echo "amd64 manifest: $AMD_DIGEST"
timeout 30 curl -s -x http://127.0.0.1:17897 -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.oci.image.manifest.v1+json" "https://registry-1.docker.io/v2/significantgravitas/autogpt/manifests/$AMD_DIGEST" -o /tmp/amd.json -w "amd manifest: %{http_code} %{size_download}B\n"
python3 -c "
import json
d=json.load(open('/tmp/amd.json'))
layers=d.get('layers',[])
print('layers:',len(layers),'total MB:',sum(l['size'] for l in layers)//1048576)
print('first blob:',layers[0]['digest'] if layers else None)
" 2>/dev/null
