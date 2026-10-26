#!/bin/bash
# Copy the WSL-side screenshots into the Windows-visible folder.
cp /d/automate/out/*.png /mnt/d/automate/out/ 2>/dev/null
ls -la /mnt/d/automate/out/*.png | head -5
