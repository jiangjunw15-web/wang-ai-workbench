#!/bin/bash
# Build the desktop client and package a single-file Windows installer.
# Produces: desktop/setup/王将军AI工作台安装程序.exe
#
# Prereqs: .NET SDK (net10.0-windows), Windows host.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD="$ROOT/WangInstaller/payload"
PUBLISH="$ROOT/publish"
SETUP="$ROOT/setup"

rm -rf "$PAYLOAD" "$SETUP"
mkdir -p "$PAYLOAD" "$SETUP"

# 0) publish the desktop app (self-contained single file)
cd "$ROOT/WangDesktop"
dotnet publish -c Release -r win-x64 --self-contained true -o "$PUBLISH"

# 1) payload: app + service launcher + relay + icon
cp "$PUBLISH/WangDesktop.exe" "$PAYLOAD/王将军AI工作台.exe"
cp "$ROOT/wang-service-start.bat" "$PAYLOAD/wang-service-start.bat"
cp "$ROOT/relay.js" "$PAYLOAD/relay.js"
cp "$ROOT/WangDesktop/Assets/wang.ico" "$PAYLOAD/wang.ico"

# 2) publish the installer (embeds the payload)
cd "$ROOT/WangInstaller"
dotnet publish -c Release -r win-x64 --self-contained true -o "$SETUP"

cp "$SETUP/安装王将军AI工作台.exe" "$SETUP/王将军AI工作台安装程序.exe"
echo "=== installer ==="
ls -la "$SETUP"/*.exe
