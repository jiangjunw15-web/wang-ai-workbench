#!/bin/bash
# Write local platform access info (runtime-generated values only) to D:\automate
set -euo pipefail
. /root/autogpt_account.env
GID=$(sed -n 1p /root/team_graph_id 2>/dev/null || echo "not-created")
cat > /mnt/d/automate/platform-info.txt <<EOF
AutoGPT Platform（本机）访问信息
=================================
前端地址      : http://localhost:3000
登录邮箱      : $EMAIL
登录密码      : $PASS
API Key       : $API_KEY
AI 团队工作流 : $GID（名称：AI创作团队）

说明
- 密码为安装时随机生成，仅存于本机两处：本文件 与 WSL 的 /root/autogpt_account.env
- API Key 用于外部 API（X-API-Key 头），全部权限
- 外部 API 基址: http://localhost:3000/_agpt/external-api/v1
- 命令行跑团队: wsl -d AutoGPT -u root -- bash /mnt/d/automate/wsl/run_team.sh "你的指令"
EOF
chmod 644 /mnt/d/automate/platform-info.txt
echo INFO_WRITTEN
