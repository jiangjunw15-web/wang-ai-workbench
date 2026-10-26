#!/bin/bash
echo "== /data layout =="
docker run --rm -v autogpt-data:/d alpine:3.20 sh -c "ls /d/; ls /d/runtime 2>/dev/null | head -20; ls /d/logs 2>/dev/null | head -20"
echo "== supervisor program logs with fatal/error =="
docker run --rm -v autogpt-data:/d alpine:3.20 sh -c '
find /d -maxdepth 3 -name "*.log" -mmin -10 2>/dev/null | head -20
echo ---
for f in $(find /d -maxdepth 3 -name "*fatal*" -o -maxdepth 3 -name "*watchdog*" 2>/dev/null | head -5); do echo "== $f =="; tail -20 "$f"; done
echo ---
grep -rlE "Traceback" /d/runtime /d/logs 2>/dev/null | head -5
'
