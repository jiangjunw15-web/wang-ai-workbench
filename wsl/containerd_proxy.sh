#!/bin/bash
set -x
mkdir -p /etc/systemd/system/containerd.service.d
cat > /etc/systemd/system/containerd.service.d/proxy.conf <<'EOF'
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:17897"
Environment="HTTPS_PROXY=http://127.0.0.1:17897"
Environment="NO_PROXY=localhost,127.0.0.1,172.17.0.1"
EOF
systemctl daemon-reload
systemctl restart containerd docker
sleep 3
docker pull significantgravitas/autogpt:latest > /root/pull.log 2>&1 &
PULLPID=$!
sleep 40
du -sh /var/lib/docker
tail -c 400 /root/pull.log
echo
echo "PULLPID=$PULLPID"
