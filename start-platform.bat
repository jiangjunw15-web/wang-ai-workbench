@echo off
chcp 65001 >nul
echo [王将军AI工作台] starting...

rem 1) Windows-side port relay (magpie 3425 -> 13425, proxy 7897 -> 17897, wang 8790 -> 18790)
tasklist /FI "IMAGENAME eq node.exe" 2>nul | find /I "node.exe" >nul || (
  start "" /min cmd /c "node D:\automate\relay.js"
)

rem 2) 王将军 local console (AI 排序管理 / Magpie 连接)
curl -s -m 3 -o NUL http://127.0.0.1:8790/wang/api/state >nul 2>&1 || (
  start "" /min cmd /c "bash D:\automate\wang\start.sh"
)

rem 3) boot WSL (systemd starts docker + the autogpt container)
wsl.exe -d AutoGPT -u root -- docker start autogpt 2>nul
wsl.exe -d AutoGPT -u root -- systemctl start wang-relay magpie-relay proxy-relay 2>nul

echo waiting for the platform to become healthy...
:wait
timeout /t 5 /nobreak >nul
wsl.exe -d AutoGPT -u root -- docker inspect --format "{{.State.Health.Status}}" autogpt 2>nul | find "healthy" >nul && goto ready
goto wait

:ready
echo.
echo ============================================================
echo   王将军AI工作台   http://localhost:3000
echo   AI 排序管理      http://localhost:3000/wang/ai-order
echo   Magpie 连接      http://localhost:3000/wang/magpie
echo   登录账号        见 D:\automate\platform-info.txt
echo ============================================================
