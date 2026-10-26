#!/bin/bash
if docker images | grep -q "significantgravitas/autogpt"; then
  echo "ALREADY_PULLED"
  docker images | grep significantgravitas
  exit 0
fi
pgrep -f "docker pull" >/dev/null && { echo "PULL_RUNNING"; exit 0; }
setsid nohup docker pull significantgravitas/autogpt:latest > /root/pull.log 2>&1 < /dev/null &
sleep 5
echo "STARTED pid=$(pgrep -f 'docker pull')"
