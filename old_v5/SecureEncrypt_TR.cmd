@echo off
title SecureEncrypt (AES-256 Encrypt ^& Decrypt^) by Abdullah ERTšRK
set "_V_SIG=9432d4f1caf8ead360d24d62bd8dc11deaa7be456350dc5e2bb5d66e87e8e32f"
setlocal enabledelayedexpansion

set "TEMP_SELF=%TEMP%\SecureEncrypt_verify_%RANDOM%.tmp"
set "skip_lines=9"
more +10 "%~f0" > "%TEMP_SELF%"
for /f "delims=" %%H in ('certutil -hashfile "%TEMP_SELF%" SHA256 2^>nul ^| findstr /v "hash" ^| findstr /r /v "^$"') do (
    set "_CALC_HASH=%%H"
)
set "_CALC_HASH=!_CALC_HASH: =!"
echo !_CALC_HASH!| clip
del "%TEMP_SELF%" 2>nul

if /i not "!_CALC_HASH!"=="%_V_SIG%" (
    mode con cols=93 lines=23
    echo.
    echo SecureEncrypt (AES-256 Encrypt ^& Decrypt^)
    echo.
    echo https://github.com/abdullah-erturk
    echo.
    echo ========================================================================
    echo             HATA: Komut Dosyas Btnlk ˜hlali
    echo ========================================================================
    echo.
    echo Bu betik de§iŸtirildi veya bozuldu.
    echo Gvenlik nedeniyle yrtme durduruldu.
    echo.
    echo Beklenen Hash  : %_V_SIG%
    echo.
    echo ========================================================================
    echo.
    echo €kŸ i‡in herhangi bir tuŸa basn...
    pause >nul
    exit /b
)

:: ============================================================================================================================================

attrib +R "%~f0" >nul 2>&1
title SecureEncrypt (AES-256 Encrypt ^& Decrypt^) by Abdullah ERTšRK
setlocal enabledelayedexpansion
set "XOR_KEY=default_xor_key_for_text_obfuscation_secure_encrypt"
set "TEMP_XOR_FLAG=%TEMP%\_xor_flag_%RANDOM%.tmp"
set "is_folder=0"
set "temp_zip="
set "PS_VER_MAJOR="
for /f "delims=" %%V in ('powershell -NoProfile -Command "if($PSVersionTable -and $PSVersionTable.PSVersion){$PSVersionTable.PSVersion.Major}else{2}" 2^>nul') do (
    set "PS_VER_MAJOR=%%V"
)
if not defined PS_VER_MAJOR set "PS_VER_MAJOR=2"
echo.
echo SecureEncrypt (AES-256 Encrypt ^& Decrypt^)
echo.
echo https://github.com/abdullah-erturk
echo.

:: ============================================================================================================================================

:: --- KURULUM / KALDIRMA B™LšMš ---
if "%~1"=="" (
    mode con cols=93 lines=23
    echo.
    echo SecureEncrypt (AES-256 Encrypt ^& Decrypt^)
    echo.
    echo.
	echo Kurulum yapmadan da kullanabilirsiniz.
    echo.
    echo žifreleme iŸlemi i‡in ltfen bu betik dosyasna bir dosya veya klas”r srkleyip brakn.
	echo.
      
    net session >nul 2>&1
    if errorlevel 1 (
		echo Kurulum i‡in Y”netici ayrcalklar gerekiyor.
		echo Y”netici izinleri isteniyor...
        echo.
        powershell -Command "Start-Process '%~f0' -Verb RunAs"
        exit /b
    )
            
    if exist "C:\Windows\SecureEncrypt.cmd" (
        echo.
        echo.
		echo SecureEncrypt sistemde zaten kurulu.
        echo.
		choice /C EH /M "Kaldrlmasn istiyor musunuz"
  	 	if !errorlevel! equ 1 (
  	 	 	echo.
			echo Kaldrlyor...
            del /f /q "C:\Windows\SecureEncrypt.cmd" >nul
            reg delete "HKCR\*\shell\SecureEncrypt" /f >nul
            reg delete "HKCR\Directory\shell\SecureEncrypt" /f >nul 2>&1
			echo.
			echo Kaldrma iŸlemi baŸaryla tamamland.
			echo.
		) else (
			echo.
			echo Kaldrma iŸlemi iptal edildi.
            echo.
        )
    ) else (
        echo.
        echo.
		echo SecureEncrypt sistemde kurulu de§il.
		echo.
		choice /C EH /M "Yklenmesini ister misiniz"
        if !errorlevel! equ 1 (
            echo.
            echo Ykleniyor...
            reg delete "HKEY_CLASSES_ROOT\*\shell\SecureEncode" /f >nul 2>&1
            del /f /q C:\Windows\SecureEncode.cmd >nul 2>&1
            copy /y "%~f0" "C:\Windows\SecureEncrypt.cmd" >nul
            attrib +R "C:\Windows\SecureEncrypt.cmd" >nul 2>&1
            
            :: Dosya men
            reg add "HKCR\*\shell\SecureEncrypt" /ve /d "Dosyay žifrele (Gvenli žifreleme AES-256)" /f >nul
            reg add "HKCR\*\shell\SecureEncrypt" /v "Icon" /d "C:\Windows\system32\imageres.dll,54" /f >nul
            reg add "HKCR\*\shell\SecureEncrypt\command" /ve /d "\"C:\Windows\SecureEncrypt.cmd\" \"%%1\"" /f >nul
            
            :: Klas”r men
            reg add "HKCR\Directory\shell\SecureEncrypt" /ve /d "Klas”r žifrele (Gvenli žifreleme AES-256)" /f >nul
            reg add "HKCR\Directory\shell\SecureEncrypt" /v "Icon" /d "C:\Windows\system32\imageres.dll,54" /f >nul
            reg add "HKCR\Directory\shell\SecureEncrypt\command" /ve /d "\"C:\Windows\SecureEncrypt.cmd\" \"%%1\"" /f >nul
            
            echo.
            echo Ykleme baŸaryla tamamland.
            echo.
			echo Dosya ve Klas”r sa§ tk mens eklendi: Dosyay/Klas”r žifrele (Gvenli žifreleme AES-256^)
        ) else (
            echo.
            echo Ykleme iptal edildi.
            echo.
        )
    )
    echo.
    echo €kŸ i‡in herhangi bir tuŸa basn...
    pause >nul
    exit /b
)

:: ============================================================================================================================================

:: === €OKLU DOSYA KONTROLš ===
if not "%~2"=="" (
    mode con cols=90 lines=15
    echo.
    echo ========================================================================
    echo                       HATA: Birden Fazla ™§e Algland
    echo ========================================================================
    echo.
    echo Ltfen bir seferde yalnzca bir klas”r veya dosyay srkleyip brakn.
    echo.
    echo ========================================================================
    echo.
    echo €kŸ i‡in herhangi bir tuŸa basn...
    pause >nul
    exit /b
)

:: ============================================================================================================================================

:: === GšVENL˜K KONTROLš (Yasakli Dizinler) ===
set "is_forbidden=0"
set "full_path=%~f1"
set "user_profile_path=%USERPROFILE%\"

set "check_user_path=!full_path:%user_profile_path%=!"
if /i not "!check_user_path!"=="!full_path!" goto :security_passed

if /i not "%~d1"=="C:" goto :security_passed

set "is_forbidden=1"

set "check_recycle=!full_path:$Recycle.Bin=!"
if not "!check_recycle!"=="!full_path!" set "is_forbidden=1"

set "check_sysvol=!full_path:System Volume Information=!"
if not "!check_sysvol!"=="!full_path!" set "is_forbidden=1"

if !is_forbidden! equ 1 (
    echo ========================== UYARI ==========================
    echo.
  	echo Dosya konumu: %~f1
  	echo.
  	echo Bu dizin bir sistem klas”rdr.
  	echo Gvenlik nedeniyle bu dizinde Ÿifreleme yaplamaz.
  	echo.
  	echo ===========================================================
  	echo.
	echo €kŸ i‡in herhangi bir tuŸa basn...
    pause >nul
    exit /b 1
)
:security_passed

:: ============================================================================================================================================

:: === KLAS”R KONTROL ===
if exist "%~1\" (
    if exist "%~1\*" (
        echo ================== KLAS™R TESP˜T ED˜LD˜ ==================
        echo Klas”r Ad: %~nx1
        echo.
        echo Klas”r i‡eri§i kontrol ediliyor...
        
        :: Klas”r boŸ mu kontrol et
        set "folder_empty=1"
        for /f %%i in ('dir /b /s "%~1" 2^>nul ^| find /c /v ""') do set "file_count=%%i"
        
        if "!file_count!"=="0" (
            echo.
            echo ========================================================================
            echo                           HATA: BoŸ Klas”r
            echo ========================================================================
            echo.
            echo "%~nx1" klas”r boŸ.
            echo BoŸ klas”rler Ÿifrelenemez.
            echo.
            echo Ltfen klas”re dosya ekleyip tekrar deneyin.
            echo.
            echo ========================================================================
            echo.
            echo €kŸ herhangi bir tuŸa basn...
            pause >nul
            exit /b 1
        )
        
        echo Klas”r !file_count! adet dosya i‡eriyor.
        echo.
        echo ZIP arŸivi oluŸturuluyor...
        echo.
        
        set "temp_zip=%~dp1%~n1_temp_%RANDOM%.zip"
        if !PS_VER_MAJOR! GEQ 5 (
            powershell -NoProfile -Command "$ProgressPreference='SilentlyContinue'; Compress-Archive -Path '%~1' -DestinationPath '!temp_zip!' -CompressionLevel Optimal -Force; if(Test-Path '!temp_zip!'){$size=(Get-Item '!temp_zip!').Length; if($size -ge 1GB){Write-Host ('ArŸiv OluŸturuldu: {0:N2} GB' -f ($size/1GB))}elseif($size -ge 1MB){Write-Host ('ArŸiv OluŸturuldu: {0:N2} MB' -f ($size/1MB))}else{Write-Host ('ArŸiv OluŸturuldu: {0:N2} KB' -f ($size/1KB))}}"
        ) else (
            echo PowerShell 5 tespit edilemedi. Eski y”ntemle zipleniyor...
            call :ZipFolderLegacy "%~1" "!temp_zip!"
        )
        
        if not exist "!temp_zip!" (
            echo.
            echo HATA: ArŸiv oluŸturma baŸarsz...
            echo.
            echo €kŸ i‡in herhangi bir tuŸa basn...
            pause >nul
            exit /b 1
        )
        
        set "src_file=!temp_zip!"
        set "src_name=%~nx1.zip"
        set "output_name_only=%~n1"
        set "is_folder=1"
        
        echo ==========================================================
        echo.
        
        goto :skip_file_check
    )
)

set "src_file=%~f1"
set "src_name=%~nx1"
set "output_name_only=%~n1"

:: ============================================================================================================================================

:skip_file_check
set "output_cmd=%~dp1%output_name_only%_decrypt.cmd"
set "temp_b64=%~dp1%output_name_only%.bin"

echo.
echo %~nx1 i‡in bir parola belirleyin. (iste§e ba§l)
echo (žifre girmezseniz %~nx1 SADECE binary veri (RAW) olarak paketlenir, ž˜FRELENMEZ)
echo.

set "user_pass="
for /f "delims=" %%p in ('powershell -ExecutionPolicy Bypass -NoProfile -Command "$securePass=Read-Host -AsSecureString -Prompt 'žifre (žifrelemeden ge‡mek i‡in ENTER tuŸuna basn)'; $bstr=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass); $password=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr); [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) | Out-Null; Write-Output $password"') do (
    set "user_pass=%%p"
)

set "ENCRYPT_FLAG=0"
if defined user_pass (
    if not "!user_pass!"=="" (
        set "ENCRYPT_FLAG=1"
        echo.
  	 	echo žifre ayarland. AES-256 ile Ÿifrelenecek.
  	 	echo.
  	 	echo ™NEML˜: BU ž˜FREY˜ UNUTMAYIN.
  	) else (
  	 	echo.
  	 	echo žifre boŸ. ž˜FRELENMEYECEK.
  	)
) else (
  	echo.
  	echo žifre girilmedi. Dosya ž˜FRELENMEYECEK.
)
echo.
echo žifreleme durumu : !ENCRYPT_FLAG! (1 = žifreli, 0 = žifresiz)
timeout /t 2 >nul

echo.

if exist "%output_cmd%" (
  	echo Mevcut Decrypt dosyas bulundu. Salt Okunur ”zniteli§i kaldrlyor...
    attrib -R "%output_cmd%" 2>nul
    del /f /q "%output_cmd%" 2>nul
    echo.
)

echo ================== ENCRYPT ˜žLEM˜ ==================
echo Kaynak Dosya    : %src_name%
set "src_size=0"
if exist "%src_file%" (
    for %%F in ("%src_file%") do set "src_size=%%~zF"
)

if "%src_size%"=="0" (
    echo.
  	echo HATA: Dosya bulunamad veya boyutu 0 bayt.
    echo.
    echo €kŸ i‡in herhangi bir tuŸa basn...
    pause >nul
    exit /b 1
)

for /f "delims=" %%S in ('powershell -NoProfile -Command "$s=%src_size%; if($s -ge 1073741824){'{0:N2} GB' -f ($s/1073741824)}elseif($s -ge 1048576){'{0:N2} MB' -f ($s/1048576)}else{'{0:N2} KB' -f ($s/1024)}"') do set "SIZE_STR=%%S"
echo Kaynak Boyutu   : !SIZE_STR! 
for /f "delims=" %%H in ('certutil -hashfile "%src_file%" SHA256 ^| findstr /v "hash" ^| findstr /r /v "^$"') do set "src_sha=%%H"
set "src_sha=%src_sha: =%"
echo Kaynak SHA256   : %src_sha%
echo.

if "!ENCRYPT_FLAG!"=="1" (
    echo ˜Ÿlem: Dosya AES-256 ile Ÿifreleniyor...
    powershell -ExecutionPolicy Bypass -NoProfile -Command "$_m=[math]; $password='!user_pass!'; $sw=New-Object Diagnostics.Stopwatch; $sw.Start(); $fileIn='%src_file%'; $fileOut='!temp_b64!'; $buffer = New-Object byte[] 65536; $fsIn = New-Object IO.FileStream($fileIn, [IO.FileMode]::Open, [IO.FileAccess]::Read); $fsOut = New-Object IO.FileStream($fileOut, [IO.FileMode]::Create, [IO.FileAccess]::Write); $salt=New-Object byte[] 16; (New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($salt); $iv=New-Object byte[] 16; (New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($iv); $fsOut.Write($salt, 0, 16); $fsOut.Write($iv, 0, 16); $kdf=New-Object System.Security.Cryptography.Rfc2898DeriveBytes($password, $salt, 10000); $key=$kdf.GetBytes(32); $aes=[System.Security.Cryptography.Aes]::Create(); $aes.Mode='CBC'; $aes.Padding='PKCS7'; $aes.Key=$key; $aes.IV=$iv; $cs=New-Object System.Security.Cryptography.CryptoStream($fsOut, $aes.CreateEncryptor(), [System.Security.Cryptography.CryptoStreamMode]::Write); $sentinelBytes = [Text.Encoding]::ASCII.GetBytes('__SECURE_ENCODE_MAGIC_BYTES_OK__'); $cs.Write($sentinelBytes, 0, $sentinelBytes.Length); $totalSize = $fsIn.Length; $totalRead = 0; $lp = -1; while (($read = $fsIn.Read($buffer, 0, $buffer.Length)) -gt 0) { $cs.Write($buffer, 0, $read); $totalRead += $read; $pct = [Math]::Floor(($totalRead / $totalSize) * 100); if ($pct -ne $lp) { $barLen = [Math]::Min(30, [Math]::Floor($pct/3.3)); $bar = '=' * $barLen; $space = ' ' * (30 - $barLen); Write-Host \"`r˜lerleme: [$bar$space] $pct%%\" -NoNewline; $lp = $pct; } }; Write-Host \"`r˜lerleme: [\" ('='*30)\"] 100%%\"; $cs.Close(); $fsOut.Close(); $fsIn.Close(); $aes.Clear(); $sw.Stop(); $ts=$sw.Elapsed; if($ts.TotalMinutes -ge 1){ Write-Host ('Sre: {0} dakika {1:F0} saniye' -f $_m::Floor($ts.TotalMinutes),$ts.Seconds) }else{ Write-Host ('Sre: {0:F2} saniye' -f $ts.TotalSeconds) }"
    set "IS_XORED=0"
) else (
    del "%TEMP_XOR_FLAG%" 2>nul
    set "IS_XORED=0"
    powershell -ExecutionPolicy Bypass -NoProfile -Command "function Is-TextFile($filePath) { $blockSize = 4096; $buffer = New-Object byte[] $blockSize; try { $fs = [IO.File]::OpenRead($filePath); $read = $fs.Read($buffer, 0, $blockSize); $fs.Close(); if ($read -eq 0) { return $true }; for ($i = 0; $i -lt $read; $i++) { if ($buffer[$i] -eq 0) { return $false } }; return $true; } catch { return $false } }; $_m=[math]; $sw=[Diagnostics.Stopwatch]::StartNew(); $fileIn='%src_file%'; $fileOut='!temp_b64!'; if (Is-TextFile($fileIn)) { Write-Host 'Metin maskeleme uygulaniyor...'; $key = [Text.Encoding]::ASCII.GetBytes('%XOR_KEY%'); $keyLen = $key.Length; $fsIn = New-Object IO.FileStream($fileIn, [IO.FileMode]::Open); $fsOut = New-Object IO.FileStream($fileOut, [IO.FileMode]::Create); $buffer = New-Object byte[] 65536; $keyIndex = 0; $totalSize = $fsIn.Length; $totalRead = 0; $lp = -1; while (($read = $fsIn.Read($buffer, 0, $buffer.Length)) -gt 0) { for ($i = 0; $i -lt $read; $i++) { $buffer[$i] = $buffer[$i] -bxor $key[$keyIndex]; $keyIndex = ($keyIndex + 1) %% $keyLen }; $fsOut.Write($buffer, 0, $read); $totalRead += $read; $totalRead += $read; $pct = [Math]::Floor(($totalRead / $totalSize) * 100); if ($pct -ne $lp) { $barLen = [Math]::Min(30, [Math]::Floor($pct/3.3)); $bar = '=' * $barLen; $space = ' ' * (30 - $barLen); Write-Host \"`r˜lerleme: [$bar$space] $pct%%\" -NoNewline; $lp = $pct; } }; Write-Host \"`r˜lerleme: [\" ('='*30)\"] 100%%\"; $fsOut.Close(); $fsIn.Close(); [IO.File]::WriteAllText('%TEMP_XOR_FLAG%', '1'); } else { Write-Host 'Ham veri kopyalaniyor...'; $fsIn = New-Object IO.FileStream($fileIn, [IO.FileMode]::Open); $fsOut = New-Object IO.FileStream($fileOut, [IO.FileMode]::Create); $buffer = New-Object byte[] 65536; $totalSize = $fsIn.Length; $totalRead = 0; $lp = -1; while (($read = $fsIn.Read($buffer, 0, $buffer.Length)) -gt 0) { $fsOut.Write($buffer, 0, $read); $totalRead += $read; $pct = [Math]::Floor(($totalRead / $totalSize) * 100); if ($pct -ne $lp) { $barLen = [Math]::Min(30, [Math]::Floor($pct/3.3)); $bar = '=' * $barLen; $space = ' ' * (30 - $barLen); Write-Host \"`r˜lerleme: [$bar$space] $pct%%\" -NoNewline; $lp = $pct; } }; Write-Host \"`r˜lerleme: [\" ('='*30)\"] 100%%\"; $fsOut.Close(); $fsIn.Close(); [IO.File]::WriteAllText('%TEMP_XOR_FLAG%', '0'); }; $sw.Stop(); $ts=$sw.Elapsed; Write-Host ('Sre: {0:F2} saniye' -f $ts.TotalSeconds)"

    if exist "%TEMP_XOR_FLAG%" (
        for /f "delims=" %%F in ('type "%TEMP_XOR_FLAG%"') do set "IS_XORED=%%F"
    )
    if not defined IS_XORED set "IS_XORED=0"
    del "%TEMP_XOR_FLAG%" 2>nul
)

:: ============================================================================================================================================

:: Ge‡ici zip dosyasn tem˜zle
if "!is_folder!"=="1" (
    if exist "!temp_zip!" (
        del /f /q "!temp_zip!" 2>nul
    )
)

for %%F in ("%temp_b64%") do set "b64_size=%%~zF"
for /f "delims=" %%S in ('powershell -NoProfile -Command "$s=%b64_size%; if($s -ge 1GB){'{0:N2} GB' -f ($s/1GB)}elseif($s -ge 1MB){'{0:N2} MB' -f ($s/1MB)}else{'{0:N2} KB' -f ($s/1KB)}"') do set "B64_SIZE_STR=%%S"
echo.
echo ˜Ÿlenen Veri Boyutu: !B64_SIZE_STR! ^(%b64_size% bytes^)
echo ======================================================

:: ============================================================================================================================================

:: === DECRYPT DOSYASINI OLUžTURMA ===
echo.
echo Decrypt dosyas oluŸturuluyor, ltfen bekleyin...

if exist "%output_cmd%" (
    attrib -R "%output_cmd%" 2>nul
    del /f /q "%output_cmd%" 2>nul
)
echo @echo off >> "%output_cmd%"
echo @title SecureEncrypt (AES-256 Encrypt ^^^& Decrypt^) >> "%output_cmd%"
echo @setlocal enabledelayedexpansion >> "%output_cmd%"
echo @pushd %%~dp0 >> "%output_cmd%"
echo @set "PS_VER_MAJOR=" >> "%output_cmd%"
echo for /f "delims=" %%%%V in ^('powershell -NoProfile -Command "if(^$PSVersionTable -and ^$PSVersionTable.PSVersion){^$PSVersionTable.PSVersion.Major}else{2}" 2^^^>nul'^) do @set "PS_VER_MAJOR=%%%%V" >> "%output_cmd%"
echo @if not defined PS_VER_MAJOR set "PS_VER_MAJOR=2" >> "%output_cmd%"
echo. >> "%output_cmd%"
for /f "delims=" %%B in ('powershell -NoProfile -Command "$fileName='%src_name%'; $bytes=[Text.Encoding]::UTF8.GetBytes($fileName); [Convert]::ToBase64String($bytes)"') do set "FNB64=%%B"
echo set "FILE_B64=!FNB64!" >> "%output_cmd%"
echo set "out_name=%src_name%" >> "%output_cmd%"
echo set "expected_sha=%src_sha%" >> "%output_cmd%"
echo set "IS_ENCRYPTED=!ENCRYPT_FLAG!" >> "%output_cmd%"
echo set "IS_XORED=!IS_XORED!" >> "%output_cmd%"
echo set "XOR_KEY=%XOR_KEY%" >> "%output_cmd%"
echo set "IS_FOLDER=!is_folder!" >> "%output_cmd%"
echo echo. >> "%output_cmd%"
echo echo SecureEncrypt (AES-256 Encrypt ^^^& Encrypt^) >> "%output_cmd%"
echo echo. >> "%output_cmd%"
echo echo https://github.com/abdullah-erturk >> "%output_cmd%"
echo echo. >> "%output_cmd%"
echo echo ================== DECRYPT ISLEMI ================== >> "%output_cmd%"
echo echo Hedef Dosya    : %%out_name%% >> "%output_cmd%"
echo echo Beklenen SHA256: %%expected_sha%% >> "%output_cmd%"
echo echo Sifreleme      : !ENCRYPT_FLAG! (1 = Evet, 0 = Hayir^) >> "%output_cmd%"
if "!is_folder!"=="1" (
    echo echo Kaynak Turu    : Klasor (Islem bitince otomatik cikarilacak^) >> "%output_cmd%"
)
echo echo Encrypt Tarihi : %date% %time% >> "%output_cmd%"
echo echo. >> "%output_cmd%"
echo. >> "%output_cmd%"
echo set "TEMP_PS=%%TEMP%%\decode_%%RANDOM%%.ps1" >> "%output_cmd%"
echo type NUL ^> "%%TEMP_PS%%" ^>nul >> "%output_cmd%"
echo echo param^([string]^$self^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo ^$ErrorActionPreference^='Stop' ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo ^$isEnc ^^^= ^([int]^$env:IS_ENCRYPTED -eq 1^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo ^$isXored ^^^= ^([int]^$env:IS_XORED -eq 1^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo ^$xorKeyBytes ^^^= [Text.Encoding]^^::ASCII.GetBytes^($env:XOR_KEY^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo try ^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     ^$marker ^^^= [Text.Encoding]^^::ASCII.GetBytes(^"`r`n::DATA::`r`n^") ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     ^$outNameB64 ^^^= ^$env:FILE_B64 ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     try ^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^$outNameBytes ^^^= [Convert]^^::FromBase64String^(^$outNameB64^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^$outName ^^^= [Text.Encoding]^^::UTF8.GetString^(^$outNameBytes^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     ^} catch ^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         Write-Host ^"HATA: Dosya adi cozumlenemedi. Base64: ^$outNameB64^" -ForegroundColor Red ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         exit 1 ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     ^$outPath ^^^= Join-Path ^(Split-Path -Parent ^$self^) ^$outName ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     Write-Host ^"Hedef dosya: ^$outName^" ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     # STREAM-BASED READING - Find marker ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     ^$fs ^^^= [IO.File]^^::OpenRead(^$self^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     ^$found ^^^= -1L ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     ^$buffer ^^^= New-Object byte[] 8192 ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     ^$pos ^^^= 0L ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     ^$markerBuf ^^^= New-Object byte[] ^$marker.Length ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     while^(^$fs.Position -lt ^$fs.Length^)^^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^$read ^^^= ^$fs.Read(^$buffer,0,^$buffer.Length^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         if^(^$read -le 0^)^^{ break ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         for^(^$i^=0^; ^$i -lt ^$read^; ^$i^^^+^^^+^)^^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             ^$markerBuf ^^^= ^$markerBuf^[1..^(^$markerBuf.Length-1^)^] ^^^+ ^$buffer^[^$i^] ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             ^$match ^^^= ^$true ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             for^(^$j^=0^; ^$j -lt ^$marker.Length^; ^$j^^^+^^^+^)^^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo                 if^(^$markerBuf^[^$j^] -ne ^$marker^[^$j^]^)^^{ ^$match ^^^= ^$false^; break ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             if^(^$match^)^^{ ^$found ^^^= ^$pos ^^^+ ^$i ^^^+ 1L^; break ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         if^(^$found -ge 0^)^^{ break ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^$pos ^^^+^^^= ^$read ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     if^(^$found -lt 0^)^^{ throw ^"DATA isareti bulunamadi (Dosya bozuk olabilir)^" ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     ^$fs.Position ^^^= ^$found ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     if^(^$isEnc^)^^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         Write-Host ^'Bu dosya sifreli. Lutfen sifrenizi girin:^' ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^$sp ^^^= Read-Host -AsSecureString -Prompt ^'Sifre^' ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^$bstr^^^=[Runtime.InteropServices.Marshal]^^::SecureStringToBSTR(^$sp^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^$pw^^^=[Runtime.InteropServices.Marshal]^^::PtrToStringAuto(^$bstr^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^[void]^[Runtime.InteropServices.Marshal]^^::ZeroFreeBSTR(^$bstr^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         # Read salt and IV ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^$salt ^^^= New-Object byte[] 16 ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^$iv     ^^^= New-Object byte[] 16 ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^[void]^$fs.Read(^$salt, 0, 16^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^[void]^$fs.Read(^$iv, 0, 16^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^$kdf ^^^= New-Object Security.Cryptography.Rfc2898DeriveBytes(^$pw,^$salt,10000^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^$key ^^^= ^$kdf.GetBytes^(32^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^$aes ^^^= [Security.Cryptography.Aes]^^::Create^() ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^$aes.Mode^='CBC'^; ^$aes.Padding^='PKCS7'^; ^$aes.Key^=^$key^; ^$aes.IV^=^$iv ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^$cs ^^^= $null ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^$fsOut ^^^= $null ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         try ^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             ^$fsOut ^^^= New-Object IO.FileStream^(^$outPath,[IO.FileMode]^^::Create^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             ^$cs ^^^= New-Object Security.Cryptography.CryptoStream^(^$fs,^$aes.CreateDecryptor^(),[Security.Cryptography.CryptoStreamMode]^^::Read^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             ^$expectedSentinel ^^^= ^'__SECURE_ENCODE_MAGIC_BYTES_OK__^' ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             ^$decSentinelBuf ^^^= New-Object byte[] 32 ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             ^$readCount ^^^= ^$cs.Read^(^$decSentinelBuf, 0, 32^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             ^if ^(^$readCount -ne 32^) ^{ throw ^"Dosya bozuk (Sentinel okunamadi)^" ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             ^$decryptedSentinelStr ^^^= [Text.Encoding]^^::ASCII.GetString^(^$decSentinelBuf^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             ^if ^(^$decryptedSentinelStr -ne ^$expectedSentinel^) ^{ throw ^"Hatali Sifre veya Bozuk Dosya^" ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             ^$buf ^^^= New-Object byte[] 65536 ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             ^while ^((^$n = ^$cs.Read(^$buf, 0, ^$buf.Length^)^) -gt 0^) ^{ ^$fsOut.Write(^$buf, 0, ^$n^) ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^} catch [System.Security.Cryptography.CryptographicException] ^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             Write-Host ^"Hatali Sifre veya Bozuk Dosya^" -ForegroundColor Red ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             if ^(^$fsOut^) ^{ ^$fsOut.Close^() ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             if ^(^$cs^) ^{ ^$cs.Close^() ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             if^(Test-Path ^$outPath^)^^{ Remove-Item ^$outPath -ErrorAction SilentlyContinue ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             exit 1 ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^} catch ^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             ^$errMsg = ^$_.Exception.Message ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             Write-Host ^"HATA: ^$errMsg^" -ForegroundColor Red ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             if ^(^$fsOut^) ^{ ^$fsOut.Close^() ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             if ^(^$cs^) ^{ ^$cs.Close^() ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             if^(Test-Path ^$outPath^)^^{ Remove-Item ^$outPath -ErrorAction SilentlyContinue ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             exit 1 ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^} finally ^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             if ^(^$fsOut^) ^{ ^$fsOut.Close^() ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             if ^(^$cs^) ^{ ^$cs.Close^() ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             if ^(^$aes^) ^{ ^$aes.Clear^() ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     ^} else ^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^$fsOut ^^^= New-Object IO.FileStream^(^$outPath,[IO.FileMode]^^::Create^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         try ^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             if ^(^$isXored^) ^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo                 ^$key = ^$xorKeyBytes; ^$keyLen = ^$key.Length; ^$keyIndex = 0 ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo                 ^$buf = New-Object byte[] 65536 ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo                 while ^((^$read = ^$fs.Read(^$buf, 0, ^$buf.Length^)^) -gt 0^) ^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo                     for (^$i = 0; ^$i -lt ^$read; ^$i++^) ^{ ^$buf[^$i] = ^$buf[^$i] -bxor ^$key[^$keyIndex]; ^$keyIndex = (^$keyIndex + 1^) %%%% ^$keyLen ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo                     ^$fsOut.Write(^$buf, 0, ^$read^) ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo                 ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             ^} else ^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo                 ^$buf ^^^= New-Object byte[] 65536 ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo                 while ^((^$n = ^$fs.Read(^$buf, 0, ^$buf.Length^)^) -gt 0^) ^{ ^$fsOut.Write(^$buf, 0, ^$n^) ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo             ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo         ^} finally ^{ ^$fsOut.Close^() ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     ^$fs.Close^() ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     if^(Test-Path ^$outPath^)^^{ ^$size^^^=^(Get-Item ^$outPath^).Length^; ^$kb^^^=^[math^]^^::Round^(^$size/1KB^)^; Write-Host ^"Dosya olusturuldu: ^$kb KB^" -ForegroundColor Green ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     if^(Test-Path ^$outPath^)^^{ ^$s^^^=^(Get-Item ^$outPath^).Length^; ^$mb^^^=^"{0:N2} MB^" -f ^(^$s/1MB^); Write-Host ^("Dosya boyutu: {0}" -f ^$mb,^$s^) ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     if^(Test-Path ^$outPath^)^^{ ^$stream^^^=[IO.File]^^::OpenRead^(^$outPath^)^; ^$sha256^^^=New-Object Security.Cryptography.SHA256Managed^; ^$hashBytes^^^=^$sha256.ComputeHash^(^$stream^)^; ^$stream.Close^()^; ^$sb^^^=New-Object Text.StringBuilder^; foreach^(^$b in ^$hashBytes^)^^{ [void]^$sb.Append^(^$b.ToString^("x2"^)^) ^^}^; ^$sha^^^=^$sb.ToString^()^; Write-Host ^"Hesaplanan SHA256: ^$sha^"^; if^(^$sha -ieq ^$env:expected_sha^)^^{ Write-Host ^"SHA256: BASARILI^" -ForegroundColor Green ^} else ^{ Write-Host ^"SHA256: HATALI^" -ForegroundColor Red ^} ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo ^} catch [System.Security.Cryptography.CryptographicException] ^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     if^(Test-Path ^$outPath^)^^{ Remove-Item ^$outPath -ErrorAction SilentlyContinue ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     exit 1 ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo ^} catch ^{ ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     ^$errMsg = ^$_.Exception.Message ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     Write-Host ^"HATA: ^$errMsg^" -ForegroundColor Red ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     if^(Test-Path ^$outPath^)^^{ Remove-Item ^$outPath -ErrorAction SilentlyContinue ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo     exit 1 ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo echo ^} ^>^> "%%TEMP_PS%%" >> "%output_cmd%"
echo powershell -ExecutionPolicy Bypass -NoProfile -File "%%TEMP_PS%%" "%%~f0" >> "%output_cmd%"
echo if errorlevel 1 ( >> "%output_cmd%"
echo     del "%%TEMP_PS%%" 2^>nul >> "%output_cmd%"
echo     if exist "%%out_name%%" del /f /q "%%out_name%%" 2^>nul >> "%output_cmd%"
echo     echo. >> "%output_cmd%"
echo     echo €kŸ i‡in herhangi bir tuŸa basn... >> "%output_cmd%"
echo     pause ^>nul >> "%output_cmd%"
echo     exit >> "%output_cmd%"
echo ) >> "%output_cmd%"
echo del "%%TEMP_PS%%" 2^>nul >> "%output_cmd%"
echo if "%%IS_FOLDER%%"=="1" ( >> "%output_cmd%"
echo     call :Win7Unzip "%%out_name%%" >> "%output_cmd%"
echo ) >> "%output_cmd%"
echo. >> "%output_cmd%"
echo echo ================== DECRYPT ISLEMI ================== >> "%output_cmd%"
echo echo. >> "%output_cmd%"
echo echo CIKIS icin herhangi bir tusa basin...>> "%output_cmd%"
echo pause ^>nul >> "%output_cmd%"
echo exit >> "%output_cmd%"
echo. >> "%output_cmd%"
echo :Win7Unzip >> "%output_cmd%"
echo setlocal >> "%output_cmd%"
echo set "ZIP_FILE=%%~dp0%%~1" >> "%output_cmd%"
echo REM Buraya cikart (Zip icinde zaten klasor varsa ic ice olusmamasi icin) >> "%output_cmd%"
echo set "EXTRACT_DIR=%%~dp0" >> "%output_cmd%"
echo. >> "%output_cmd%"
echo echo Icerik cikariliyor, ltfen bekleyin... >> "%output_cmd%"
echo. >> "%output_cmd%"
echo REM VBScript veya Batch hatasi olmamasi icin dogrudan PowerShell 2.0 kullaniyoruz >> "%output_cmd%"
echo powershell -NoProfile -Command "$sh=new-object -com shell.application; $zip=$sh.NameSpace('%%ZIP_FILE%%'); $dest=$sh.NameSpace('%%EXTRACT_DIR%%'); $dest.CopyHere($zip.Items(), 16)" >> "%output_cmd%"
echo if not errorlevel 1 ( >> "%output_cmd%"
echo     del /f /q "%%ZIP_FILE%%" 2^>nul >> "%output_cmd%"
echo     echo Cikarma islemi tamamlandi. >> "%output_cmd%"
echo ) else ( >> "%output_cmd%"
echo     echo HATA: Cikarma basarisiz. ZIP dosyasi korundu. >> "%output_cmd%"
echo ) >> "%output_cmd%"
echo endlocal >> "%output_cmd%"
echo exit /b >> "%output_cmd%"
echo. >> "%output_cmd%"

(echo ::DATA::) >> "%output_cmd%"

if not exist "%output_cmd%" (
    echo.
    echo HATA: Decrypt dosya oluŸturulamad...
    echo €kŸ i‡in herhangi bir tuŸa basn...
    pause >nul
    exit /b 1
)

echo Decrypt komut dosyas baŸaryla oluŸturuldu.
echo.

if not exist "%temp_b64%" (
    echo HATA: Binary dosya bulunamad: %temp_b64%
    echo €kŸ i‡in herhangi bir tuŸa basn...
    pause >nul
    exit /b 1
)

for %%F in ("%temp_b64%") do set "bin_size=%%~zF"
for /f "delims=" %%S in ('powershell -NoProfile -Command "$s=%bin_size%; if($s -ge 1GB){'{0:N2} GB' -f ($s/1GB)}elseif($s -ge 1MB){'{0:N2} MB' -f ($s/1MB)}else{'{0:N2} KB' -f ($s/1KB)}"') do set "BIN_SIZE_STR=%%S"
echo Binary dosya boyutu: !BIN_SIZE_STR! 
echo Binary veri Decrypt dosyasna yazlyor, ltfen bekleyin...
echo.

copy /b "%output_cmd%" + "%temp_b64%" "%output_cmd%.tmp" >nul 2>&1
if errorlevel 1 (
  	echo HATA: Binary veri birleŸtirme baŸarsz^!
	echo €kŸ i‡in herhangi bir tuŸa basn...
    pause >nul
    exit /b 1
)

move /y "%output_cmd%.tmp" "%output_cmd%" >nul
if errorlevel 1 (
  	echo HATA: Dosya de§iŸtirme baŸarsz^!
	echo €kŸ i‡in herhangi bir tuŸa basn...
    pause >nul
    exit /b 1
)

del "%temp_b64%" 2>nul
if exist "%TEMP_XOR_FLAG%" del /f /q "%TEMP_XOR_FLAG%" 2>nul

if "!is_folder!"=="1" (
    if exist "!temp_zip!" (
        del /f /q "!temp_zip!" 2>nul
    )
)

for %%F in ("%output_cmd%") do set "final_size=%%~zF"
for /f "delims=" %%S in ('powershell -NoProfile -Command "$s=%final_size%; if($s -ge 1GB){'{0:N2} GB' -f ($s/1GB)}elseif($s -ge 1MB){'{0:N2} MB' -f ($s/1MB)}else{'{0:N2} KB' -f ($s/1KB)}"') do set "FINAL_SIZE_STR=%%S"
echo Decrypt Dosya Boyutu: !FINAL_SIZE_STR! 

attrib +R "%output_cmd%"

echo.
echo BAžARILI - Tm iŸlemler tamamland.
echo.
echo Decrypt dosyas: %output_cmd%
echo.
if "!is_folder!"=="1" (
    echo NOT: Bu bir klas”rdr. žifre ‡”zme iŸleminden sonra otomatik olarak zip'ten ‡karlacaktr...
    echo.
)
echo ˜Ÿlem tamamland.
echo.
echo €kŸ i‡in herhangi bir tuŸa basn...
pause >nul
exit /b 0

:: ============================================================================================================================================

:ZipFolderLegacy
setlocal EnableExtensions EnableDelayedExpansion
set "src_folder=%~f1"
set "dest_zip=%~f2"
if not defined src_folder exit /b 1
if not defined dest_zip exit /b 1
if exist "!dest_zip!" del /f /q "!dest_zip!" >nul 2>&1
call :EscapeForVBS "%src_folder%" src_folder_vbs
call :EscapeForVBS "%dest_zip%" dest_zip_vbs
set "zip_vbs_script=%TEMP%\zip_%RANDOM%.vbs"
>"!zip_vbs_script!" echo Set fso = CreateObject("Scripting.FileSystemObject")
>>"!zip_vbs_script!" echo zipFile = fso.GetAbsolutePathName("!dest_zip_vbs!")
>>"!zip_vbs_script!" echo Set ts = fso.CreateTextFile(zipFile, True)
>>"!zip_vbs_script!" echo ts.Write "PK" ^& Chr(5) ^& Chr(6) ^& String(18, Chr(0))
>>"!zip_vbs_script!" echo ts.Close
>>"!zip_vbs_script!" echo Set sh = CreateObject("Shell.Application")
>>"!zip_vbs_script!" echo Set src = sh.Namespace("!src_folder_vbs!")
>>"!zip_vbs_script!" echo If src Is Nothing Then WScript.Quit 1
>>"!zip_vbs_script!" echo Set dst = sh.Namespace(zipFile)
>>"!zip_vbs_script!" echo If dst Is Nothing Then WScript.Quit 1
>>"!zip_vbs_script!" echo Set parentFolder = sh.Namespace(fso.GetParentFolderName("!src_folder_vbs!"))
>>"!zip_vbs_script!" echo Set folderItem = parentFolder.ParseName(fso.GetFileName("!src_folder_vbs!"))
>>"!zip_vbs_script!" echo dst.CopyHere folderItem, 16
>>"!zip_vbs_script!" echo Do
>>"!zip_vbs_script!" echo      WScript.Sleep 200
>>"!zip_vbs_script!" echo Loop Until dst.Items.Count ^>= 1
cscript //nologo "!zip_vbs_script!"
set "zip_rc=%errorlevel%"
del "!zip_vbs_script!" >nul 2>&1
endlocal & exit /b %zip_rc%

:: ============================================================================================================================================

:EscapeForVBS
setlocal EnableDelayedExpansion
set "str=%~1"
set "str=%str:"=""%"
endlocal & set "%~2=%str%"
exit /b 0