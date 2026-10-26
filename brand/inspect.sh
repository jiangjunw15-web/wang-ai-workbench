#!/bin/bash
docker cp /mnt/d/automate/brand/inspect_dom.py autogpt:/tmp/inspect_dom.py
docker exec autogpt python /tmp/inspect_dom.py 2>&1 | head -24
