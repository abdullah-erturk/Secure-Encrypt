@echo off
rem Builds SecureEncrypt.cmd: drag src\build.ps1 onto this file, or just double-click it.
rem No administrator rights are needed (the build only writes next to the sources).
set "SE_BUILD=%~1"
if "%SE_BUILD%"=="" set "SE_BUILD=%~dp0build.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SE_BUILD%"
echo.
pause
