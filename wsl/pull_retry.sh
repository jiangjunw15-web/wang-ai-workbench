#!/bin/bash
for attempt in 1 2 3 4 5; do
  echo "=== attempt $attempt ==="
  docker pull --platform linux/amd64 significantgravitas/autogpt:latest > /root/pull.log 2>&1
  if docker images | grep -q significantgravitas; then
    echo PULL_SUCCESS
    docker images | grep significantgravitas
    exit 0
  fi
  tr '\r' '\n' < /root/pull.log | grep -v '^$' | tail -2
  sleep 15
done
echo PULL_FAILED_ALL
