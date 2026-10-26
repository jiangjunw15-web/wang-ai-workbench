#!/bin/bash
set -x
pkill -f "docker pull" 2>/dev/null || true
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/proxy.conf <<'EOF'
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:17897"
Environment="HTTPS_PROXY=http://127.0.0.1:17897"
Environment="NO_PROXY=localhost,127.0.0.1,172.17.0.1"
EOF
systemctl daemon-reload
systemctl restart docker
sleep 2
systemctl is-active docker
timeout 30 curl -s -o /dev/null -w "mirror-daocloud: %{http_code}\n" https://docker.m.daocloud.io/v2/ || echo "mirror-daocloud: FAIL"
timeout 30 curl -s -x http://127.0.0.1:17897 -o /dev/null -w "dockerhub-via-proxy: %{http_code}\n" https://registry-1.docker.io/v2/ || echo "dockerhub-via-proxy: FAIL"
