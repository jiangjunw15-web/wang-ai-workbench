@echo off
rem 王将军AI工作台桌面端服务启动器（本机专用）
setlocal
set "WANG_ROOT=%~dp0"

rem WSL 中的容器和 relay 服务（幂等）
wsl.exe -d AutoGPT -u root -- docker start autogpt >nul 2>&1
wsl.exe -d AutoGPT -u root -- systemctl start wang-relay magpie-relay proxy-relay >nul 2>&1

rem Windows 端中继：仅当 13425 还未监听时启动（避免重复 node 进程）
netstat -ano 2>nul | findstr /R /C:":13425 .*LISTENING" >nul
if errorlevel 1 start "王将军AI中继" /min node "%WANG_ROOT%relay.js"

exit /b 0
