@echo off
@title SecureEncrypt (AES-256 Encrypt ^& Decrypt)
@setlocal DisableDelayedExpansion
set "SE_SELF=%~f0"
set "SE_PS=%TEMP%\SecureEncrypt_dec_%RANDOM%%RANDOM%.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f=[IO.File]::OpenRead($env:SE_SELF);$b=New-Object byte[] 262144;$n=$f.Read($b,0,$b.Length);$f.Close();$s=[Text.Encoding]::GetEncoding(28591).GetString($b,0,$n);$a=$s.IndexOf('#PS_'+'BEGIN'+[char]13+[char]10)+11;$e=$s.IndexOf('#PS_'+'END'+[char]13+[char]10);[IO.File]::WriteAllText($env:SE_PS,$s.Substring($a,$e-$a),(New-Object Text.UTF8Encoding($true)))"
if not exist "%SE_PS%" (
    echo ERROR: Could not extract the decoder. Windows PowerShell is required.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SE_PS%"
set "SE_RC=%ERRORLEVEL%"
del /f /q "%SE_PS%" >nul 2>&1
exit /b %SE_RC%
