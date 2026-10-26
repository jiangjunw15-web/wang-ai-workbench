#!/bin/bash
# Relay the 王将军 console (Windows:8790) into the WSL network so the
# container's nginx can reach it.
set -euo pipefail
cat > /usr/local/bin/wang-relay.sh <<'EOF'
#!/bin/bash
for i in $(seq 1 30); do
  GW=$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}')
  [ -n "$GW" ] && break
  sleep 2
done
echo "[wang-relay] Windows gateway: $GW"
exec socat TCP-LISTEN:18790,bind=0.0.0.0,fork,reuseaddr TCP:${GW}:18790
EOF
chmod +x /usr/local/bin/wang-relay.sh

cat > /etc/systemd/system/wang-relay.service <<'EOF'
[Unit]
Description=Relay to the Windows-side 王将军 console (18790)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/wang-relay.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable wang-relay.service
systemctl restart wang-relay.service
sleep 2
systemctl is-active wang-relay
