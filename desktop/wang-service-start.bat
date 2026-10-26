@echo off
rem Wang AI Workbench desktop service launcher (machine-independent).
rem Reads optional wang-service.env next to this script for site-specific
rem values (WSL distro, container name). Defaults are generic.
setlocal
set "WANG_ROOT=%~dp0"

rem --- site config (all optional) ---
set "WSL_DISTRO=wang-workbench"
set "CONTAINER=wang-workbench"
if exist "%WANG_ROOT%wang-service.env" (
  for /f "usebackq tokens=1,* delims==" %%A in ("%WANG_ROOT%wang-service.env") do (
    set "%%A=%%B"
  )
)

rem --- WSL container + relay services (idempotent) ---
wsl.exe -d "%WSL_DISTRO%" -u root -- docker start "%CONTAINER%" >nul 2>&1
wsl.exe -d "%WSL_DISTRO%" -u root -- systemctl start wang-relay magpie-relay proxy-relay >nul 2>&1

rem --- Windows port relay: only start if not already listening ---
netstat -ano 2>nul | findstr /R /C:":13425 .*LISTENING" >nul
if errorlevel 1 start "WangRelay" /min node "%WANG_ROOT%relay.js"

exit /b 0
