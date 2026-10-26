#!/bin/bash
cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.1ms.run"
  ],
  "log-driver": "json-file",
  "log-opts": { "max-size": "50m", "max-file": "5" }
}
EOF
systemctl restart docker containerd
sleep 3
timeout 300 docker pull --platform linux/amd64 significantgravitas/autogpt:latest > /root/pull1ms.log 2>&1
RC=$?
echo "PULL_RC=$RC"
tr '\r' '\n' < /root/pull1ms.log | grep -v '^$' | tail -6
docker images | grep significantgravitas || true
