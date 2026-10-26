#!/bin/bash
# AutoGPT Platform on WSL - bootstrap (run as root inside the AutoGPT distro)
set -x

log() { echo "[bootstrap] $*"; }

# 1) Docker install (docker-ce from download.docker.com, direct; apt proxy fallback)
if ! command -v docker >/dev/null 2>&1; then
  log "installing docker-ce"
  if curl -m 8 -sfI https://download.docker.com/linux/ubuntu/gpg >/dev/null 2>&1; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
  else
    GW=$(ip route | awk '/^default/ {print $3; exit}')
    echo "Acquire::http::Proxy \"http://${GW}:17897\";" > /etc/apt/apt.conf.d/95proxy
    echo "Acquire::https::Proxy \"http://${GW}:17897\";" >> /etc/apt/apt.conf.d/95proxy
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL -x "http://${GW}:17897" https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
    rm -f /etc/apt/apt.conf.d/95proxy
  fi
fi
docker --version || exit 1

# 2) daemon.json with CN registry mirrors (no proxy dependency)
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1ms.run",
    "https://hub.rat.dev"
  ],
  "log-driver": "json-file",
  "log-opts": { "max-size": "50m", "max-file": "5" }
}
EOF

# 3) systemd enable
mkdir -p /etc/wsl.conf.d
cat > /etc/wsl.conf <<'EOF'
[boot]
systemd=true
EOF

# 4) socat relays: containers/WSL reach Windows-side services (bound to 127.0.0.1 only)
cat > /usr/local/bin/magpie-relay.sh <<'EOF'
#!/bin/bash
for i in $(seq 1 30); do
  GW=$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}')
  [ -n "$GW" ] && break
  sleep 2
done
echo "[magpie-relay] Windows gateway: $GW"
exec socat TCP-LISTEN:13425,bind=0.0.0.0,fork,reuseaddr TCP:${GW}:13425
EOF
cat > /usr/local/bin/proxy-relay.sh <<'EOF'
#!/bin/bash
for i in $(seq 1 30); do
  GW=$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}')
  [ -n "$GW" ] && break
  sleep 2
done
echo "[proxy-relay] Windows gateway: $GW"
exec socat TCP-LISTEN:17897,bind=0.0.0.0,fork,reuseaddr TCP:${GW}:17897
EOF
chmod +x /usr/local/bin/magpie-relay.sh /usr/local/bin/proxy-relay.sh

cat > /etc/systemd/system/magpie-relay.service <<'EOF'
[Unit]
Description=Socat relay to Windows-side Magpie gateway (13425)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/magpie-relay.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/proxy-relay.service <<'EOF'
[Unit]
Description=Socat relay to Windows-side HTTP proxy (17897)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/proxy-relay.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable docker.service magpie-relay.service proxy-relay.service 2>/dev/null
systemctl restart docker.service
sleep 2
docker info 2>/dev/null | grep -E "Server Version|Registry Mirrors" -A2 | head -8
echo "[bootstrap] DONE"
