#!/bin/bash
echo "== direct curl auth.docker.io via proxy =="
timeout 20 curl -s -o /dev/null -w "auth_via_127: %{http_code} %{time_total}s\n" "http://127.0.0.1:17897/xx" 2>/dev/null
timeout 25 curl -s -x http://127.0.0.1:17897 -o /dev/null -w "authdockerio: %{http_code} %{time_total}s\n" "https://auth.docker.io/token?service=registry.docker.io&scope=repository:alpine:pull" || echo "authdockerio: TIMEOUT"
echo "== daocloud manifest for autogpt =="
timeout 25 curl -s -o /dev/null -w "daocloud_manifest: %{http_code} %{time_total}s\n" "https://docker.m.daocloud.io/v2/significantgravitas/autogpt/manifests/latest" -H "Accept: application/vnd.oci.image.index.v1+json" || echo "daocloud_manifest: TIMEOUT"
echo "== daocloud blob test (first layer we know: fc80f55e 8.6MB) =="
timeout 30 curl -s -r 0-1000 -o /dev/null -w "daocloud_blob: %{http_code} %{size_download}B\n" "https://docker.m.daocloud.io/v2/significantgravitas/autogpt/blobs/sha256:fc80f55e752ce53ca2f5d6dd42d6137f72783fef6f8eda6703a3101b5992d297" || echo "daocloud_blob: TIMEOUT"
