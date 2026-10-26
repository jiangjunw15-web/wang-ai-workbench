@echo off
chcp 65001 >nul
wsl.exe -d AutoGPT -u root -- docker stop autogpt
echo AutoGPT Platform stopped (WSL still running; close it with: wsl --shutdown)
