#!/bin/bash
set -x
pkill -f "docker pull" 2>/dev/null || true
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "50m", "max-file": "5" }
}
EOF
systemctl restart docker containerd
sleep 3
setsid nohup docker pull --platform linux/amd64 significantgravitas/autogpt:latest > /root/pull.log 2>&1 < /dev/null &
sleep 30
du -sh /var/lib/docker
tr '\r' '\n' < /root/pull.log | grep -v '^$' | tail -4
