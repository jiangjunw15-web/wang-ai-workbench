#!/bin/bash
# Assemble the installer payload (embedded resources) and publish a single setup.exe.
set -euo pipefail
ROOT=/d/automate/desktop
PAYLOAD="$ROOT/WangInstaller/payload"
PUBLISH="$ROOT/publish"
SETUP="$ROOT/setup"

rm -rf "$PAYLOAD" "$SETUP"
mkdir -p "$PAYLOAD" "$SETUP"

# 0) Always publish the desktop app first; do not depend on stale output.
cd "$ROOT/WangDesktop"
dotnet publish -c Release -r win-x64 --self-contained true -o "$PUBLISH" >/tmp/wangdesktop-publish.log 2>&1
[ -f "$PUBLISH/WangDesktop.exe" ] || { tail -50 /tmp/wangdesktop-publish.log; exit 1; }

# 1) desktop app (renamed to the product name)
cp "$PUBLISH/WangDesktop.exe" "$PAYLOAD/王将军AI工作台.exe"
# 2) service launcher + relay used by the desktop app to bring the platform up
cp "$ROOT/wang-service-start.bat" "$PAYLOAD/wang-service-start.bat"
cp "$ROOT/../relay.js" "$PAYLOAD/relay.js"
# 3) icon
cp "$ROOT/WangDesktop/Assets/wang.ico" "$PAYLOAD/wang.ico"

cd "$ROOT/WangInstaller"
dotnet publish -c Release -r win-x64 --self-contained true -o "$ROOT/setup" 2>&1 | tail -3

cp "$ROOT/setup/安装王将军AI工作台.exe" "$ROOT/setup/王将军AI工作台安装程序.exe"
echo "=== setup output ==="
ls -la "$ROOT/setup"/*.exe
