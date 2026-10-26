#!/bin/bash
docker cp /mnt/d/automate/brand/dump_logo.py autogpt:/tmp/dump_logo.py
docker exec autogpt python /tmp/dump_logo.py 2>&1 | head -40
