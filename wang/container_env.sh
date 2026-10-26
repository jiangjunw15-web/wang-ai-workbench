#!/bin/bash
# Personal-installation environment for the 王将军AI工作台 container.
# Persisted as a docker-compose-style env file the run script sources.
set -euo pipefail

cat > /mnt/d/automate/wang/container-env.txt <<'EOF'
# 单机自用：关闭注册（只保留本机管理员账户）
AUTH_ALLOW_NEW_ACCOUNTS=false
# 关闭一切外发遥测
POSTHOG_API_KEY=
POSTHOG_HOST=
LANGFUSE_PUBLIC_KEY=
LANGFUSE_SECRET_KEY=
LANGFUSE_HOST=
SENTRY_DSN=
GRAPHITI_TELEMETRY_ENABLED=false
MEM0_TELEMETRY=false
# 关闭付费/订阅相关后端提示
STRIPE_API_KEY=
STRIPE_WEBHOOK_SECRET=
POSTMARK_SERVER_API_TOKEN=
POSTMARK_WEBHOOK_TOKEN=
MAILERLITE_API_TOKEN=
MAILERLITE_ONBOARDING_GROUP_ID=
MAILERLITE_CHANGELOG_GROUP_ID=
MAILERLITE_TRIAL_GROUP_ID=
MAILERLITE_CHECKOUT_GROUP_ID=
MAILERLITE_WEBHOOK_SECRET=
TYPESAFE_API_KEY=
# 保持本机模型网关为唯一模型来源
MAGPIE_BASE_URL=http://172.17.0.1:13425/v1
MAGPIE_API_KEY=magpie
CHAT_USE_LOCAL=true
CHAT_BASE_URL=http://172.17.0.1:13425/v1
CHAT_API_KEY=magpie
CHAT_FAST_STANDARD_MODEL=group/free
EOF

echo "container-env written:"
wc -l /mnt/d/automate/wang/container-env.txt
