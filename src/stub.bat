@echo off
@title SecureEncrypt (AES-256 Encrypt ^& Decrypt)
@setlocal DisableDelayedExpansion
set "SE_SELF=%~f0"
set "SE_PS=%TEMP%\SecureEncrypt_dec_%RANDOM%%RANDOM%.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f=[IO.File]::OpenRead($env:SE_SELF);$b=New-Object byte[] 262144;$n=$f.Read($b,0,$b.Length);$f.Close();$s=[Text.Encoding]::GetEncoding(28591).GetString($b,0,$n);$a=$s.IndexOf('#PS_'+'BEGIN'+[char]13+[char]10)+11;$e=$s.IndexOf('#PS_'+'END'+[char]13+[char]10);[IO.File]::WriteAllText($env:SE_PS,$s.Substring($a,$e-$a),(New-Object Text.UTF8Encoding($true)))"
if not exist "%SE_PS%" (
    echo ERROR: Could not extract the decoder. Windows PowerShell is required.
    pause
    (goto) 2>nul & cmd /d /c exit 1
)
:: NOTE: every exit below is "(goto) 2>nul & cmd /d /c exit N" and not "exit /b N": for a file larger than 4 GB cmd.exe
:: otherwise goes on reading the file at a wrong offset after "exit /b" and runs the binary data as commands.
:: Window mode: the decoder runs hidden and detached and this console window closes at once (SE_GUI=0 keeps the text mode).
set "SE_DETACH=1"
if "%SE_GUI%"=="0" set "SE_DETACH="
if defined SE_DETACH (
    set "SE_DETACHED=1"
    start "" /min powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SE_PS%"
    (goto) 2>nul & cmd /d /c exit 0
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SE_PS%"
set "SE_RC=%ERRORLEVEL%"
del /f /q "%SE_PS%" >nul 2>&1
(goto) 2>nul & cmd /d /c exit %SE_RC%
