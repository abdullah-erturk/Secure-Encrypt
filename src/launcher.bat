@echo off
title SecureEncrypt (AES-256 Encrypt ^& Decrypt^) by Abdullah ERTURK
set "_V_SIG=__SIG__"
setlocal enabledelayedexpansion

set "TEMP_SELF=%TEMP%\SecureEncrypt_verify_%RANDOM%.tmp"
set "skip_lines=9"
more +10 "%~f0" > "%TEMP_SELF%"
for /f "delims=" %%H in ('certutil -hashfile "%TEMP_SELF%" SHA256 2^>nul ^| findstr /v "hash" ^| findstr /r /v "^$"') do (
    set "_CALC_HASH=%%H"
)
set "_CALC_HASH=!_CALC_HASH: =!"
del "%TEMP_SELF%" 2>nul

if /i not "!_CALC_HASH!"=="%_V_SIG%" (
    mode con cols=93 lines=23
    echo.
    echo SecureEncrypt (AES-256 Encrypt ^& Decrypt^)
    echo.
    echo https://github.com/abdullah-erturk
    echo.
    echo https://erturk-dev.netlify.app
    echo.
    echo ========================================================================
    echo             ERROR: Script Integrity Violation
    echo ========================================================================
    echo.
    echo This script has been modified or corrupted.
    echo Execution stopped for security reasons.
    echo.
    echo Expected Hash   : %_V_SIG%
    echo Calculated Hash : !_CALC_HASH!
    echo.
    echo ========================================================================
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

:: ============================================================================================================================================
:: The program itself is a PowerShell script appended to this file (after the marker comment line "#@@" + "PS").
:: It is extracted to %TEMP% and started with every argument passed through unchanged.
:: ============================================================================================================================================

attrib +R "%~f0" >nul 2>&1
mode con cols=100 lines=40 >nul 2>&1
endlocal
setlocal DisableDelayedExpansion
set "SE_SELF=%~f0"
set "SE_PS=%TEMP%\SecureEncrypt_%RANDOM%%RANDOM%.ps1"
more +__PSLINE__ "%~f0" > "%SE_PS%" 2>nul
if not exist "%SE_PS%" (
    echo ERROR: Could not extract the program. Windows PowerShell is required.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SE_PS%" %*
set "SE_RC=%ERRORLEVEL%"
del /f /q "%SE_PS%" >nul 2>&1
exit /b %SE_RC%
