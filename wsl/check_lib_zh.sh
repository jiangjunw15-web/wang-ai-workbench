#!/bin/bash
# Fetch /library HTML with a valid session and report zh/en phrase counts.
set -euo pipefail
. /root/autogpt_account.env
curl -s -m 20 -c /tmp/cj.txt -X POST http://localhost:3000/api/auth/sign-in/email \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}" -o /dev/null
curl -s -m 15 -b /tmp/cj.txt -L http://localhost:3000/library -o /tmp/lib.html
echo "size=$(stat -c %s /tmp/lib.html)"
for pair in "工作流简报:Workflow Briefing" "正在运行:Running now" "最近完成:Recently completed" "需要关注:Needs attention" "所有工作流:All Workflows" "排序方式:sort by" "最后修改:Last Modified" "查看任务:See tasks" "你的任务控制台:Your mission control." "收藏:Favorites" "创建文件夹:Create folder"; do
  ZH="${pair%%:*}"; EN="${pair##*:}"
  Z=$(grep -c "$ZH" /tmp/lib.html || true)
  E=$(grep -c "$EN" /tmp/lib.html || true)
  echo "$ZH=$Z | $EN=$E"
done
