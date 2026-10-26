#!/bin/bash
set -x
pkill -f "docker pull" 2>/dev/null || true
cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io"
  ],
  "log-driver": "json-file",
  "log-opts": { "max-size": "50m", "max-file": "5" }
}
EOF
systemctl restart docker containerd
sleep 3
for attempt in 1 2 3 4 5 6 7 8; do
  docker pull --platform linux/amd64 significantgravitas/autogpt:latest > /root/pull.log 2>&1
  if docker images | grep -q significantgravitas; then
    echo "PULL_SUCCESS_AT=$attempt"
    docker images | grep significantgravitas
    exit 0
  fi
  echo "--- attempt $attempt tail ---"
  tr '\r' '\n' < /root/pull.log | grep -v '^$' | tail -2
  sleep 10
done
echo PULL_FAILED_ALL
