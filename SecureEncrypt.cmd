@echo off
title SecureEncrypt (AES-256 Encrypt ^& Decrypt^) by Abdullah ERTURK
set "_V_SIG=5749f89b6dc9e2bec7fb05ab427d391e85a8f3d9a3f93b0033880311f0705b3c"
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
more +62 "%~f0" > "%SE_PS%" 2>nul
if not exist "%SE_PS%" (
    echo ERROR: Could not extract the program. Windows PowerShell is required.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SE_PS%" %*
set "SE_RC=%ERRORLEVEL%"
del /f /q "%SE_PS%" >nul 2>&1
exit /b %SE_RC%
#@@PS
$ErrorActionPreference = 'Stop'
$SelfPath = $env:SE_SELF
$Version = '6.0'
$IsTR = ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'tr')
if ($env:SE_LANG) { $IsTR = ($env:SE_LANG -eq 'tr') }

# ---------------------------------------------------------------- texts

$M_EN = @{
    press         = 'Press any key to exit...'
    use_hint1     = 'You can use it without installation.'
    use_hint2     = 'To encrypt files or folders, drag and drop them onto this script (several at once is fine).'
    need_admin    = 'Administrator privileges required for installation. Requesting permission...'
    admin_denied  = 'Administrator permission was not granted.'
    installed     = 'SecureEncrypt is already installed on the system.'
    menu          = '  [1] Update / reinstall|  [2] Uninstall|  [3] Exit'
    choice        = 'Your choice [1/2/3] (type the number, then press ENTER)'
    not_installed = 'SecureEncrypt is not installed on the system.'
    q_install     = 'Do you want to install it'
    installing    = 'Installing...'
    install_ok    = 'Installation completed successfully.'
    install_menu  = 'Right-click menu added: Encrypt for files/folders, Decrypt for *_decrypt.cmd files.'
    uninstalling  = 'Uninstalling...'
    uninstall_ok  = 'Uninstallation completed successfully.'
    cancelled     = 'Cancelled.'
    menu_encrypt  = 'Encrypt (Secure Encrypt AES-256)'
    menu_dec      = 'Decrypt (Secure Encrypt)'
    warning       = '========================== WARNING =========================='
    forbidden     = 'This location is a system folder. Encryption cannot be performed here for security reasons.'
    notfound      = 'Path not found: {0}'
    items         = 'Items to process ({0}):'
    more_items    = '  ... and {0} more'
    t_pw          = 'Password (press ENTER to skip)'
    t_pw2         = 'Confirm password'
    pw_strength   = 'Password strength: {0}'
    strength0     = 'very weak'
    strength1     = 'weak'
    strength2     = 'fair'
    strength3     = 'good'
    strength4     = 'strong'
    pw_mismatch   = 'Passwords do not match. Try again.'
    pw_weak       = 'This password is weak. Use it anyway?'
    q_adv         = 'Advanced options (key file, delete originals)'
    t_kf          = 'Key file (path, drag a file here, or ? to browse; ENTER to skip)'
    kf_missing    = 'Key file not found: {0}'
    kf_pick_title = 'Select the key file'
    kf_pick_fail  = 'The file dialog could not be opened (for example on Server Core). Please type the path instead.'
    late_added    = 'Added {0} more selected item(s) - {1} in total.'
    late_skipped  = 'Skipped (system folder): {0}'
    kf_note       = 'NOTE: if the content of this key file changes or the file is lost, your data can no longer be opened. Keep a backup copy.'
    no_enc        = 'No password or key file: data will NOT be encrypted (only compressed and obfuscated).'
    enc_on        = 'Encryption: AES-256-CBC + HMAC-SHA256, key from PBKDF2-SHA256 ({0} iterations).'
    dont_forget   = 'IMPORTANT: DO NOT FORGET THIS PASSWORD / KEY FILE. Without it the data cannot be recovered.'
    t_delete      = 'What should happen to the original item(s) after encryption?|  [N] Keep them (default)|  [D] Delete them|  [S] Overwrite, then delete them'
    t_delete_ask  = 'Your choice [N/D/S] (ENTER = N)'
    exists_q      = 'Output file already exists: {0}  Overwrite?'
    section       = '================== ENCRYPT PROCESS =================='
    src_info      = 'Entries  : {0}    Total size: {1}'
    src_sha       = 'SHA256   : {0}'
    mode_label    = 'Mode     : {0}'
    mode1         = 'compressed + obfuscated (NOT encrypted)'
    mode2         = 'AES-256 encrypted'
    comp_on       = 'GZip compressed'
    comp_off      = 'not compressed (already compressed type)'
    skipped       = 'Skipped (not accessible / link): {0}'
    out_info      = 'Decrypt file: {0}  ({1})'
    verified      = 'Verification passed (output decrypted and compared).'
    changed       = 'A source file changed while it was being processed. Please try again.'
    empty         = 'Nothing to encrypt.'
    err           = 'ERROR: {0}'
    del_skip      = 'Originals were NOT deleted (the output is inside a source folder, or some items were skipped).'
    del_ok        = 'Original item(s) deleted.'
    del_fail      = 'Could not delete all originals: {0}'
    del_partial   = 'Some originals could NOT be deleted ({0}); the rest were deleted:'
    del_partial_hint = 'The encrypted copy is complete. Close whatever is using these files and delete them manually.'
    elapsed       = 'Time: {0}'
    success       = 'SUCCESS - All operations completed.'
    lbl_hash      = 'Hashing   '
    lbl_pack      = 'Packing   '
    lbl_ver       = 'Verifying '
    kdf           = 'Deriving key (PBKDF2)...'
    compile       = 'The helper code could not be compiled (.NET Framework is required). Details:'
    yn            = 'Y/N'
    yes_chars     = 'y,yes'
    no_chars      = 'n,no'
    yn_invalid    = 'Please answer {0} or {1} (or press ENTER for the default).'
}

$M_TR = @{
    press         = '\u00c7\u0131k\u0131\u015f i\u00e7in herhangi bir tu\u015fa bas\u0131n...'
    use_hint1     = 'Kurulum yapmadan da kullanabilirsiniz.'
    use_hint2     = 'Dosya veya klas\u00f6rleri \u015fifrelemek i\u00e7in bu beti\u011fin \u00fczerine s\u00fcr\u00fckleyip b\u0131rak\u0131n (birden fazla olabilir).'
    need_admin    = 'Kurulum i\u00e7in Y\u00f6netici ayr\u0131cal\u0131klar\u0131 gerekiyor. \u0130zin isteniyor...'
    admin_denied  = 'Y\u00f6netici izni verilmedi.'
    installed     = 'SecureEncrypt sistemde zaten kurulu.'
    menu          = '  [1] G\u00fcncelle / yeniden kur|  [2] Kald\u0131r|  [3] \u00c7\u0131k\u0131\u015f'
    choice        = 'Se\u00e7iminiz [1/2/3] (numaray\u0131 yaz\u0131p ENTER''a bas\u0131n)'
    not_installed = 'SecureEncrypt sistemde kurulu de\u011fil.'
    q_install     = 'Kurmak istiyor musunuz'
    installing    = 'Kuruluyor...'
    install_ok    = 'Kurulum ba\u015far\u0131yla tamamland\u0131.'
    install_menu  = 'Sa\u011f t\u0131k men\u00fcs\u00fc eklendi: dosya/klas\u00f6rler i\u00e7in \u015eifrele, *_decrypt.cmd dosyalar\u0131 i\u00e7in \u015eifreyi \u00c7\u00f6z.'
    uninstalling  = 'Kald\u0131r\u0131l\u0131yor...'
    uninstall_ok  = 'Kald\u0131rma i\u015flemi ba\u015far\u0131yla tamamland\u0131.'
    cancelled     = '\u0130ptal edildi.'
    menu_encrypt  = '\u015eifrele (Secure Encrypt AES-256)'
    menu_dec      = '\u015eifreyi \u00c7\u00f6z (Secure Encrypt)'
    warning       = '========================== UYARI =========================='
    forbidden     = 'Bu konum bir sistem klas\u00f6r\u00fcd\u00fcr. G\u00fcvenlik nedeniyle burada \u015fifreleme yap\u0131lamaz.'
    notfound      = 'Yol bulunamad\u0131: {0}'
    items         = '\u0130\u015flenecek \u00f6\u011feler ({0}):'
    more_items    = '  ... ve {0} \u00f6\u011fe daha'
    t_pw          = 'Parola (atlamak i\u00e7in ENTER)'
    t_pw2         = 'Parolay\u0131 do\u011frulay\u0131n'
    pw_strength   = 'Parola g\u00fcc\u00fc: {0}'
    strength0     = '\u00e7ok zay\u0131f'
    strength1     = 'zay\u0131f'
    strength2     = 'orta'
    strength3     = 'iyi'
    strength4     = 'g\u00fc\u00e7l\u00fc'
    pw_mismatch   = 'Parolalar e\u015fle\u015fmiyor. Tekrar deneyin.'
    pw_weak       = 'Bu parola zay\u0131f. Yine de kullan\u0131ls\u0131n m\u0131?'
    q_adv         = 'Geli\u015fmi\u015f se\u00e7enekler (anahtar dosyas\u0131, orijinalleri silme)'
    t_kf          = 'Anahtar dosyas\u0131 (yol yaz\u0131n, dosyay\u0131 s\u00fcr\u00fckleyin veya ? yaz\u0131p se\u00e7in; atlamak i\u00e7in ENTER)'
    kf_missing    = 'Anahtar dosyas\u0131 bulunamad\u0131: {0}'
    kf_pick_title = 'Anahtar dosyas\u0131n\u0131 se\u00e7in'
    kf_pick_fail  = 'Dosya se\u00e7me penceresi a\u00e7\u0131lamad\u0131 (\u00f6rne\u011fin Server Core). L\u00fctfen yolu yaz\u0131n.'
    late_added    = 'Se\u00e7ilen {0} \u00f6\u011fe daha eklendi - toplam {1}.'
    late_skipped  = 'Atland\u0131 (sistem klas\u00f6r\u00fc): {0}'
    kf_note       = 'NOT: Bu anahtar dosyas\u0131n\u0131n i\u00e7eri\u011fi de\u011fi\u015firse veya dosya kaybolursa verinize bir daha ula\u015f\u0131lamaz. Yede\u011fini saklay\u0131n.'
    no_enc        = 'Parola veya anahtar dosyas\u0131 yok: veri \u015e\u0130FRELENMEYECEK (yaln\u0131zca s\u0131k\u0131\u015ft\u0131r\u0131l\u0131r ve gizlenir).'
    enc_on        = '\u015eifreleme: AES-256-CBC + HMAC-SHA256, anahtar PBKDF2-SHA256 ({0} yineleme) ile t\u00fcretilir.'
    dont_forget   = '\u00d6NEML\u0130: BU PAROLAYI / ANAHTAR DOSYASINI UNUTMAYIN. Onsuz verinin geri getirilmesi m\u00fcmk\u00fcn de\u011fildir.'
    t_delete      = '\u015eifrelemeden sonra orijinal \u00f6\u011felere ne yap\u0131ls\u0131n?|  [N] Kals\u0131n (varsay\u0131lan)|  [D] Silinsin|  [S] \u00dczerine yaz\u0131l\u0131p silinsin'
    t_delete_ask  = 'Se\u00e7iminiz [N/D/S] (ENTER = N)'
    exists_q      = '\u00c7\u0131kt\u0131 dosyas\u0131 zaten var: {0}  \u00dczerine yaz\u0131ls\u0131n m\u0131?'
    section       = '================== \u015e\u0130FRELEME \u0130\u015eLEM\u0130 =================='
    src_info      = '\u00d6\u011fe say\u0131s\u0131: {0}    Toplam boyut: {1}'
    src_sha       = 'SHA256    : {0}'
    mode_label    = 'Mod       : {0}'
    mode1         = 's\u0131k\u0131\u015ft\u0131r\u0131lm\u0131\u015f + gizlenmi\u015f (\u015e\u0130FREL\u0130 DE\u011e\u0130L)'
    mode2         = 'AES-256 ile \u015fifreli'
    comp_on       = 'GZip ile s\u0131k\u0131\u015ft\u0131r\u0131ld\u0131'
    comp_off      = 's\u0131k\u0131\u015ft\u0131r\u0131lmad\u0131 (zaten s\u0131k\u0131\u015ft\u0131r\u0131lm\u0131\u015f t\u00fcr)'
    skipped       = 'Atland\u0131 (eri\u015filemiyor / ba\u011flant\u0131): {0}'
    out_info      = '\u00c7\u00f6z\u00fcc\u00fc dosya: {0}  ({1})'
    verified      = 'Do\u011frulama ba\u015far\u0131l\u0131 (\u00e7\u0131kt\u0131 \u00e7\u00f6z\u00fcl\u00fcp kar\u015f\u0131la\u015ft\u0131r\u0131ld\u0131).'
    changed       = '\u0130\u015flem s\u0131ras\u0131nda bir kaynak dosya de\u011fi\u015fti. L\u00fctfen tekrar deneyin.'
    empty         = '\u015eifrelenecek bir \u015fey yok.'
    err           = 'HATA: {0}'
    del_skip      = 'Orijinaller S\u0130L\u0130NMED\u0130 (\u00e7\u0131kt\u0131 bir kaynak klas\u00f6r\u00fcn i\u00e7inde ya da baz\u0131 \u00f6\u011feler atland\u0131).'
    del_ok        = 'Orijinal \u00f6\u011fe(ler) silindi.'
    del_fail      = 'Orijinallerin tamam\u0131 silinemedi: {0}'
    del_partial   = 'Baz\u0131 orijinaller S\u0130L\u0130NEMED\u0130 ({0}); geri kalanlar silindi:'
    del_partial_hint = '\u015eifreli kopya eksiksiz olu\u015fturuldu. Bu dosyalar\u0131 kullanan program\u0131 kapat\u0131p elle silebilirsiniz.'
    elapsed       = 'S\u00fcre: {0}'
    success       = 'BA\u015eARILI - T\u00fcm i\u015flemler tamamland\u0131.'
    lbl_hash      = '\u00d6zet al\u0131n\u0131yor'
    lbl_pack      = 'Paketleniyor '
    lbl_ver       = 'Do\u011frulan\u0131yor '
    kdf           = 'Anahtar t\u00fcretiliyor (PBKDF2)...'
    compile       = 'Yard\u0131mc\u0131 kod derlenemedi (.NET Framework gerekli). Ayr\u0131nt\u0131lar:'
    yn            = 'E/H'
    yes_chars     = 'e,evet,y'
    no_chars      = 'h,hay\u0131r,hayir,n'
    yn_invalid    = 'L\u00fctfen {0} veya {1} yaz\u0131n (varsay\u0131lan i\u00e7in ENTER).'
}

function T([string]$k) {
    if ($IsTR) { return [regex]::Unescape($M_TR[$k]) }
    return $M_EN[$k]
}

# explicit parameters: `-f $args` misbehaves with 2+ values on PowerShell 2.0
function TF([string]$k, $a0, $a1) {
    return [string]::Format((T $k), $a0, $a1)
}

# ---------------------------------------------------------------- helpers

$CompressedExt = @('.zip', '.7z', '.rar', '.gz', '.bz2', '.xz', '.cab', '.jpg', '.jpeg', '.png', '.gif', '.webp',
    '.mp3', '.aac', '.ogg', '.flac', '.mp4', '.mkv', '.avi', '.mov', '.webm', '.wmv', '.docx', '.xlsx', '.pptx',
    '.odt', '.ods', '.odp', '.apk', '.jar', '.msi', '.iso', '.pdf')

function Wait-Key {
    Write-Host
    Write-Host (T 'press')
    try { [void][Console]::ReadKey($true) } catch { }
}

function Show-Banner {
    Write-Host
    Write-Host "SecureEncrypt v$Version (AES-256 Encrypt & Decrypt)"
    Write-Host
    Write-Host 'https://github.com/abdullah-erturk'
    Write-Host
    Write-Host 'https://erturk-dev.netlify.app'
    Write-Host
}

function Ask-YN([string]$text, [bool]$default) {
    $yes = (T 'yes_chars').Split(',')
    $no = (T 'no_chars').Split(',')
    $letters = (T 'yn').Split('/')
    if ($default) { $hint = '[' + $letters[0] + '/' + $letters[1].ToLower() + ']' } else { $hint = '[' + $letters[0].ToLower() + '/' + $letters[1] + ']' }
    while ($true) {
        $a = (Read-Host "$text $hint").Trim().ToLowerInvariant()
        if ($a.Length -eq 0) { return $default }
        if ($yes -contains $a) { return $true }
        if ($no -contains $a) { return $false }
        # anything else (a typo, a pasted path, ...) is never taken as an answer: ask again
        Write-Host (TF 'yn_invalid' $letters[0] $letters[1]) -ForegroundColor Yellow
    }
}
function Fmt-Size([double]$n) {
    if ($n -ge 1GB) { return ('{0:N2} GB' -f ($n / 1GB)) }
    if ($n -ge 1MB) { return ('{0:N2} MB' -f ($n / 1MB)) }
    return ('{0:N2} KB' -f ($n / 1KB))
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Forbidden([string]$full) {
    $up = $env:USERPROFILE.TrimEnd('\') + '\'
    if ($full.StartsWith($up, [StringComparison]::OrdinalIgnoreCase)) { return $false }
    $root = [IO.Path]::GetPathRoot($full).TrimEnd('\')
    if ($root -ieq $env:SystemDrive) { return $true }
    foreach ($bad in @('$Recycle.Bin', 'System Volume Information')) {
        if ($full.IndexOf($bad, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
    }
    return $false
}

# The C# compiler (csc.exe) is started with an ANSI command line, so a %TEMP% path with characters outside the
# system code page (e.g. a Chinese user name on an English Windows) breaks Add-Type. Only in that case the
# compile uses an ASCII-only folder; %TEMP% is restored right afterwards (the right-click queue uses it).
function Add-LibType {
    $oldTemp = $env:TEMP; $oldTmp = $env:TMP
    try {
        if ([IO.Path]::GetTempPath() -match '[^\x00-\x7F]') {
            $cands = @()
            try { $fso = New-Object -ComObject Scripting.FileSystemObject; $cands += $fso.GetFolder([IO.Path]::GetTempPath().TrimEnd('\')).ShortPath } catch { }
            $cands += (Join-Path $env:ProgramData 'SecureEncrypt_tmp')
            $cands += 'C:\Users\Public\SecureEncrypt_tmp'
            $cands += (Join-Path $env:SystemRoot 'Temp')
            foreach ($c in $cands) {
                if (-not $c -or $c -match '[^\x00-\x7F]') { continue }
                try {
                    if (-not (Test-Path -LiteralPath $c)) { New-Item -ItemType Directory -Path $c -Force | Out-Null }
                    $probe = Join-Path $c ('p' + [Guid]::NewGuid().ToString('N') + '.tmp')
                    [IO.File]::WriteAllText($probe, 'x'); Remove-Item -LiteralPath $probe -Force
                    $env:TEMP = $c; $env:TMP = $c
                    break
                } catch { }
            }
        }
        Add-Type -TypeDefinition $LibSrc -Language CSharp
    } finally {
        $env:TEMP = $oldTemp; $env:TMP = $oldTmp
    }
}

function Ensure-Lib {
    try {
        Add-LibType
    } catch {
        Write-Host (T 'compile') -ForegroundColor Red
        Write-Host $_.Exception.Message
        Wait-Key
        exit 1
    }
    [SE.Core]::LblHash = (T 'lbl_hash')
    [SE.Core]::LblEncode = (T 'lbl_pack')
    [SE.Core]::LblVerify = (T 'lbl_ver')
    [SE.Core]::LblKdf = (T 'kdf')
}

# ---------------------------------------------------------------- install / uninstall

function Set-Verb([string]$sub, [string]$label, [string]$cmd, [string]$appliesTo) {
    $k = [Microsoft.Win32.Registry]::ClassesRoot.CreateSubKey($sub)
    $k.SetValue('', $label)
    $k.SetValue('Icon', (Join-Path $env:SystemRoot 'system32\imageres.dll') + ',54')
    if ($appliesTo) { $k.SetValue('AppliesTo', $appliesTo) }
    $c = $k.CreateSubKey('command')
    $c.SetValue('', $cmd)
    $c.Close()
    $k.Close()
}

function Remove-Key([string]$sub) {
    try { [Microsoft.Win32.Registry]::ClassesRoot.DeleteSubKeyTree($sub) } catch { }
}

function Test-WshEnabled {
    foreach ($hive in @([Microsoft.Win32.Registry]::LocalMachine, [Microsoft.Win32.Registry]::CurrentUser)) {
        try {
            $k = $hive.OpenSubKey('Software\Microsoft\Windows Script Host\Settings')
            if ($k -ne $null) {
                $v = $k.GetValue('Enabled')
                $k.Close()
                if ($v -ne $null -and [int]$v -eq 0) { return $false }
            }
        } catch { }
    }
    return (Test-Path -LiteralPath (Join-Path $env:SystemRoot 'System32\wscript.exe'))
}

function Do-Uninstall([string]$target) {
    Write-Host
    Write-Host (T 'uninstalling')
    $shim = Join-Path $env:SystemRoot 'SecureEncrypt.js'
    if (Test-Path -LiteralPath $shim) {
        [IO.File]::SetAttributes($shim, [IO.FileAttributes]::Normal)
        Remove-Item -LiteralPath $shim -Force
    }
    if (Test-Path -LiteralPath $target) {
        [IO.File]::SetAttributes($target, [IO.FileAttributes]::Normal)
        Remove-Item -LiteralPath $target -Force
    }
    Remove-Key '*\shell\SecureEncrypt'
    Remove-Key 'Directory\shell\SecureEncrypt'
    Remove-Key 'cmdfile\shell\SecureEncryptDecrypt'
    Write-Host
    Write-Host (T 'uninstall_ok') -ForegroundColor Green
}

function Do-Install([string]$target) {
    Write-Host
    Write-Host (T 'installing')
    # leftovers of the old "SecureEncode" releases
    Remove-Key '*\shell\SecureEncode'
    $old = Join-Path $env:SystemRoot 'SecureEncode.cmd'
    if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Force }

    if (Test-Path -LiteralPath $target) { [IO.File]::SetAttributes($target, [IO.FileAttributes]::Normal) }
    if ($SelfPath -ine $target) { Copy-Item -LiteralPath $SelfPath -Destination $target -Force }
    [IO.File]::SetAttributes($target, [IO.FileAttributes]::ReadOnly)

    # Explorer starts one process per selected item. The wscript helper (no console window) collects them
    # and starts a single SecureEncrypt window. Without Windows Script Host fall back to the built-in queue.
    if (Test-WshEnabled) {
        $shim = Join-Path $env:SystemRoot 'SecureEncrypt.js'
        if (Test-Path -LiteralPath $shim) { [IO.File]::SetAttributes($shim, [IO.FileAttributes]::Normal) }
        [IO.File]::WriteAllText($shim, $ShimSrc, [Text.Encoding]::ASCII)
        [IO.File]::SetAttributes($shim, [IO.FileAttributes]::ReadOnly)
        $enc = 'wscript.exe //B //Nologo "' + $shim + '" "%1"'
    } else {
        $enc = '"' + $target + '" /q "%1"'
    }
    Set-Verb '*\shell\SecureEncrypt' (T 'menu_encrypt') $enc $null
    Set-Verb 'Directory\shell\SecureEncrypt' (T 'menu_encrypt') $enc $null
    Set-Verb 'cmdfile\shell\SecureEncryptDecrypt' (T 'menu_dec') 'cmd.exe /c ""%1""' 'System.FileName:"*_decrypt.cmd"'
    Write-Host
    Write-Host (T 'install_ok') -ForegroundColor Green
    Write-Host (T 'install_menu')
}

function Show-InstallMenu {
    Show-Banner
    Write-Host (T 'use_hint1')
    Write-Host (T 'use_hint2')
    Write-Host
    if (-not (Test-Admin)) {
        Write-Host (T 'need_admin')
        try {
            Start-Process -FilePath $SelfPath -Verb RunAs
        } catch {
            Write-Host (T 'admin_denied') -ForegroundColor Red
            Wait-Key
        }
        return
    }
    $target = Join-Path $env:SystemRoot 'SecureEncrypt.cmd'
    if (Test-Path -LiteralPath $target) {
        Write-Host (T 'installed')
        foreach ($line in (T 'menu').Split('|')) { Write-Host $line }
        $c = (Read-Host (T 'choice')).Trim()
        if ($c -eq '1') { Do-Install $target }
        elseif ($c -eq '2') { Do-Uninstall $target }
        else { Write-Host (T 'cancelled') }
    } else {
        Write-Host (T 'not_installed')
        if (Ask-YN (T 'q_install') $true) { Do-Install $target } else { Write-Host (T 'cancelled') }
    }
    Wait-Key
}

# ---------------------------------------------------------------- right-click multi selection

# Explorer starts one process per selected item. Every instance drops its path into a queue
# folder; the first one to take the mutex becomes the leader and processes all queued paths.
function Wait-Queue([string]$path) {
    $dir = Join-Path $env:TEMP 'SecureEncrypt_queue'
    [void][IO.Directory]::CreateDirectory($dir)
    $mine = Join-Path $dir ([Guid]::NewGuid().ToString('N') + '.txt')
    [IO.File]::WriteAllText($mine, $path, [Text.Encoding]::UTF8)
    $mx = New-Object Threading.Mutex($false, 'Local\SecureEncryptQueue')
    # wait until no new item has arrived for 1.5 s (slow machines start the instances late), at most 15 s
    $lastCount = @(Get-ChildItem -LiteralPath $dir -Filter '*.txt').Count
    $quiet = 0
    $waited = 0
    while ($quiet -lt 1500 -and $waited -lt 15000) {
        Start-Sleep -Milliseconds 250
        $waited += 250
        $now = @(Get-ChildItem -LiteralPath $dir -Filter '*.txt').Count
        if ($now -ne $lastCount) { $lastCount = $now; $quiet = 0 } else { $quiet += 250 }
    }
    while ($true) {
        if (-not (Test-Path -LiteralPath $mine)) { exit 0 }
        $got = $false
        try { $got = $mx.WaitOne(300) } catch { $got = $true }
        if ($got) { break }
    }
    if (-not (Test-Path -LiteralPath $mine)) { exit 0 }
    $list = @()
    foreach ($f in (Get-ChildItem -LiteralPath $dir -Filter '*.txt')) {
        if ($f.LastWriteTime -gt (Get-Date).AddMinutes(-10)) {
            $p = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8).Trim()
            if ($p.Length -gt 0 -and ($list -notcontains $p)) { $list += $p }
        }
        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
    }
    return ($list | Sort-Object)
}

# ---------------------------------------------------------------- encrypt

# Items that the right-click helper queued after this window had already been started.
function Get-LateItems {
    $dir = Join-Path $env:TEMP 'SecureEncrypt_queue'
    $list = @()
    if (-not (Test-Path -LiteralPath $dir)) { return $list }
    foreach ($f in (Get-ChildItem -LiteralPath $dir -Filter '*.txt')) {
        try {
            $p = [IO.File]::ReadAllText($f.FullName).Trim()
            Remove-Item -LiteralPath $f.FullName -Force
            if ($p.Length -gt 0) { $list += $p }
        } catch { }
    }
    return $list
}

# Releases the leader role of the right-click helper (it keeps watching the lock until it disappears).
function Remove-LeaderLock {
    $lock = Join-Path (Join-Path $env:TEMP 'SecureEncrypt_queue') 'leader.lock'
    if (Test-Path -LiteralPath $lock) { Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue }
}

# "?" at a key file prompt opens a file dialog. The dialog runs in its own STA PowerShell: Windows PowerShell 2.0
# starts as MTA, which cannot show it, and a failure there (e.g. Server Core) must not break this window.
# Returns the path, '' when cancelled, or $null when the dialog could not be shown.
function Pick-File([string]$title) {
    $out = Join-Path ([IO.Path]::GetTempPath()) ('SE_pick_' + [Guid]::NewGuid().ToString('N') + '.txt')
    $script = @(
        'try {',
        '    Add-Type -AssemblyName System.Windows.Forms',
        '    $owner = New-Object System.Windows.Forms.Form',
        '    $owner.TopMost = $true; $owner.ShowInTaskbar = $false',
        '    $d = New-Object System.Windows.Forms.OpenFileDialog',
        '    $d.Title = $env:SE_PICK_TITLE; $d.CheckFileExists = $true; $d.Filter = "All files|*.*"',
        '    $r = $d.ShowDialog($owner)',
        '    $owner.Dispose()',
        '    if ($r -eq [System.Windows.Forms.DialogResult]::OK) { [IO.File]::WriteAllText($env:SE_PICK_OUT, "OK:" + $d.FileName, [Text.Encoding]::Unicode) }',
        '} catch { [IO.File]::WriteAllText($env:SE_PICK_OUT, "ERR:" + $_.Exception.Message, [Text.Encoding]::Unicode) }'
    ) -join "`r`n"
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
    $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $oldTitle = $env:SE_PICK_TITLE; $oldOut = $env:SE_PICK_OUT
    $env:SE_PICK_TITLE = $title; $env:SE_PICK_OUT = $out
    $result = ''
    try {
        Start-Process -FilePath $psExe -ArgumentList @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $enc) -WindowStyle Hidden -Wait | Out-Null
        if (Test-Path -LiteralPath $out) {
            $txt = [IO.File]::ReadAllText($out, [Text.Encoding]::Unicode)
            if ($txt.StartsWith('OK:')) { $result = $txt.Substring(3) } else { $result = $null }
        }
    } catch {
        $result = $null
    } finally {
        $env:SE_PICK_TITLE = $oldTitle; $env:SE_PICK_OUT = $oldOut
        if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue }
    }
    return $result
}

function Invoke-Encrypt([string[]]$paths, [bool]$late) {
    Show-Banner

    $items = New-Object System.Collections.ArrayList
    foreach ($p in $paths) {
        $p = $p.Trim().Trim('"')
        if ($p.Length -eq 0) { continue }
        if (-not (Test-Path -LiteralPath $p)) {
            Write-Host (TF 'notfound' $p) -ForegroundColor Red
            Wait-Key
            exit 1
        }
        $full = [IO.Path]::GetFullPath($p)
        if ($full.Length -gt 3) { $full = $full.TrimEnd('\') }
        if (Test-Forbidden $full) {
            Write-Host (T 'warning')
            Write-Host
            Write-Host $full
            Write-Host
            Write-Host (T 'forbidden')
            Wait-Key
            exit 1
        }
        if ($items -notcontains $full) { [void]$items.Add($full) }
    }
    if ($items.Count -eq 0) { Write-Host (T 'empty') -ForegroundColor Red; Wait-Key; exit 1 }

    Ensure-Lib

    Write-Host (TF 'items' $items.Count)
    $shown = 0
    foreach ($it in $items) {
        if ($shown -ge 8) { Write-Host (TF 'more_items' ($items.Count - 8)); break }
        Write-Host ('  ' + $it)
        $shown++
    }
    Write-Host

    # --- password
    $pw = New-Object Security.SecureString
    $ok = $false
    for ($attempt = 0; $attempt -lt 3; $attempt++) {
        $pw1 = Read-Host -AsSecureString (T 't_pw')
        if ($pw1.Length -eq 0) { $pw = $pw1; $ok = $true; break }
        $s = [SE.Core]::Strength($pw1)
        if ($s -le 1) { $col = 'Red' } elseif ($s -eq 2) { $col = 'Yellow' } else { $col = 'Green' }
        Write-Host (TF 'pw_strength' (T "strength$s")) -ForegroundColor $col
        if ($s -le 1 -and -not (Ask-YN (T 'pw_weak') $false)) { continue }
        $pw2 = Read-Host -AsSecureString (T 't_pw2')
        if ([SE.Core]::SecureEquals($pw1, $pw2)) { $pw = $pw1; $ok = $true; break }
        Write-Host (T 'pw_mismatch') -ForegroundColor Red
    }
    if (-not $ok) { Write-Host (T 'cancelled'); Wait-Key; exit 1 }

    # --- advanced options (key file, originals) are only asked on request
    $adv = Ask-YN (T 'q_adv') $false

    # --- key file
    $kf = $null
    while ($adv) {
        $k = (Read-Host (T 't_kf')).Trim().Trim('"')
        if ($k.Length -eq 0) { break }
        if ($k -eq '?') {
            $picked = Pick-File (T 'kf_pick_title')
            if ($picked -eq $null) { Write-Host (T 'kf_pick_fail') -ForegroundColor Yellow; continue }
            if ($picked.Length -eq 0) { continue }
            $k = $picked
        }
        if (Test-Path -LiteralPath $k -PathType Leaf) {
            $kf = [IO.Path]::GetFullPath($k)
            Write-Host (T 'kf_note') -ForegroundColor Yellow
            break
        }
        Write-Host (TF 'kf_missing' $k) -ForegroundColor Red
    }

    $secret = [SE.Core]::MakeSecret($pw, $kf)
    $usesPw = ($pw.Length -gt 0)
    $usesKf = ($kf -ne $null)
    Write-Host
    if ($secret -eq $null) {
        Write-Host (T 'no_enc') -ForegroundColor Yellow
    } else {
        Write-Host (TF 'enc_on' ([SE.Core]::DefaultIterations))
        Write-Host (T 'dont_forget') -ForegroundColor Yellow
    }
    Write-Host

    # --- the output is always written next to the (first) source item
    $outDir = Split-Path -Parent $items[0]
    if (-not $outDir) { $outDir = $items[0] }


    # --- originals
    $d = ''
    if ($adv) {
        foreach ($line in (T 't_delete').Split('|')) { Write-Host $line }
        $d = (Read-Host (T 't_delete_ask')).Trim().ToLowerInvariant()
    }
    $delMode = 0
    if ($d -eq 'd') { $delMode = 1 } elseif ($d -eq 's') { $delMode = 2 }

    # --- stragglers of a right-click multi selection (queued while the questions above were answered)
    if ($late) {
        $added = 0
        foreach ($lp in (Get-LateItems)) {
            if (-not (Test-Path -LiteralPath $lp)) { continue }
            $lf = [IO.Path]::GetFullPath($lp)
            if ($lf.Length -gt 3) { $lf = $lf.TrimEnd('\') }
            if (Test-Forbidden $lf) { Write-Host (TF 'late_skipped' $lf) -ForegroundColor Yellow; continue }
            if ($items -notcontains $lf) { [void]$items.Add($lf); $added++ }
        }
        if ($added -gt 0) {
            $addedText = [string]$added
            $totalText = [string]$items.Count
            Write-Host (TF 'late_added' $addedText $totalText) -ForegroundColor Green
        }
        Remove-LeaderLock
    }

    # --- output name
    $first = [string]$items[0]
    $leaf = [IO.Path]::GetFileName($first.TrimEnd('\'))
    if (-not $leaf) { $leaf = 'Drive_' + $first.Substring(0, 1) }
    if (Test-Path -LiteralPath $first -PathType Leaf) { $base = [IO.Path]::GetFileNameWithoutExtension($leaf) } else { $base = $leaf }
    if ($items.Count -gt 1) { $base = ('{0}_and_{1}_more' -f $base, ($items.Count - 1)) }
    $outCmd = Join-Path $outDir ($base + '_decrypt.cmd')
    $part = $outCmd + '.part'

    Write-Host
    if (Test-Path -LiteralPath $outCmd) {
        if (-not (Ask-YN (TF 'exists_q' $outCmd) $false)) { Write-Host (T 'cancelled'); Wait-Key; exit 1 }
        [IO.File]::SetAttributes($outCmd, [IO.FileAttributes]::Normal)
        Remove-Item -LiteralPath $outCmd -Force
    }
    if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Force }

    # --- text part of the self extracting file
    $decPs = '$LibSrc = @' + "'" + "`r`n" + $LibSrc + "`r`n" + "'@" + "`r`n" + $DecSrc
    $head = $StubSrc + "`r`n" + '#PS_' + "BEGIN`r`n" + $decPs + "`r`n" + '#PS_' + "END`r`n"
    if ($head -cmatch '[^\x00-\x7F]') { throw 'internal: non-ASCII header' }
    [IO.File]::WriteAllText($part, $head, [Text.Encoding]::ASCII)

    $gzip = $true
    if ($items.Count -eq 1 -and (Test-Path -LiteralPath $first -PathType Leaf)) {
        if ($CompressedExt -contains [IO.Path]::GetExtension($first).ToLower()) { $gzip = $false }
    }

    Write-Host (T 'section')
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        [SE.Core]::Encode([string[]]$items.ToArray([string]), $part, $outCmd, $gzip, $secret, $usesPw, $usesKf, [SE.Core]::DefaultIterations, ($delMode -gt 0))
    } catch {
        if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue }
        $ex = $_.Exception
        if ($ex.InnerException -ne $null) { $ex = $ex.InnerException }
        Write-Host
        if ($ex.Message -eq 'CHANGED') { Write-Host (T 'changed') -ForegroundColor Red }
        elseif ($ex.Message -eq 'EMPTY') { Write-Host (T 'empty') -ForegroundColor Red }
        else { Write-Host (TF 'err' $ex.Message) -ForegroundColor Red }
        Wait-Key
        exit 1
    } finally {
        if ($secret -ne $null) { [Array]::Clear($secret, 0, $secret.Length) }
    }
    $sw.Stop()

    Move-Item -LiteralPath $part -Destination $outCmd -Force
    [IO.File]::SetAttributes($outCmd, [IO.FileAttributes]::ReadOnly)

    Write-Host
    $cntText = [string][SE.Core]::LastCount
    $totText = Fmt-Size ([SE.Core]::LastTotal)
    Write-Host (TF 'src_info' $cntText $totText)
    Write-Host (TF 'src_sha' ([SE.Core]::LastSha))
    if ($secret -eq $null) { $modeText = T 'mode1' } else { $modeText = T 'mode2' }
    if ($gzip) { $modeText += ', ' + (T 'comp_on') } else { $modeText += ', ' + (T 'comp_off') }
    Write-Host (TF 'mode_label' $modeText)
    foreach ($sk in [SE.Core]::Skipped) { Write-Host (TF 'skipped' $sk) -ForegroundColor Yellow }
    if ($delMode -gt 0) { Write-Host (T 'verified') -ForegroundColor Green }
    $outSizeText = Fmt-Size ([SE.Core]::LastOutSize)
    Write-Host (TF 'out_info' $outCmd $outSizeText)
    $ts = $sw.Elapsed
    if ($ts.TotalMinutes -ge 1) { $tt = ('{0} min {1:F0} s' -f [math]::Floor($ts.TotalMinutes), $ts.Seconds) } else { $tt = ('{0:F2} s' -f $ts.TotalSeconds) }
    Write-Host (TF 'elapsed' $tt)

    # --- optionally remove the originals
    if ($delMode -gt 0) {
        $inside = $false
        foreach ($it in $items) {
            if ((Test-Path -LiteralPath $it -PathType Container) -and $outCmd.StartsWith($it.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { $inside = $true }
        }
        if ($inside -or ([SE.Core]::Skipped.Count -gt 0)) {
            Write-Host (T 'del_skip') -ForegroundColor Yellow
        } else {
            try {
                [SE.Core]::DeleteItems([string[]]$items.ToArray([string]), ($delMode -eq 2))
                if ([SE.Core]::DeleteFailed.Count -eq 0) {
                    Write-Host (T 'del_ok') -ForegroundColor Green
                } else {
                    $failCount = [string][SE.Core]::DeleteFailed.Count
                    Write-Host (TF 'del_partial' $failCount) -ForegroundColor Red
                    foreach ($fl in [SE.Core]::DeleteFailed) { Write-Host ('  ' + $fl) -ForegroundColor Red }
                    Write-Host (T 'del_partial_hint') -ForegroundColor Yellow
                }
            } catch {
                Write-Host (TF 'del_fail' $_.Exception.Message) -ForegroundColor Red
            }
        }
    }

    Write-Host
    Write-Host (T 'success') -ForegroundColor Green
    Write-Host
    Write-Host (T 'section')
    Wait-Key
}

$LibSrc = @'
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Runtime.InteropServices;
using System.Security;
using System.Security.Cryptography;
using System.Text;

namespace SE
{
public class Entry
{
public string Full;
public string Rel;
public bool IsDir;
public long Length;
public long MTime;
public int Attr;

public Entry(string full, string rel, bool isDir, long length, long mtime, int attr)
{
Full = full; Rel = rel; IsDir = isDir; Length = length; MTime = mtime; Attr = attr;
}
}

public class ProgressBar
{
public static string Label = "";
private long total;
private long done;
private int last = -1;

public ProgressBar(long total) { this.total = total; Draw(); }

public void Add(long n) { done += n; Draw(); }

private void Draw()
{
int pct = total <= 0 ? 100 : (int)(done * 100 / total);
if (pct > 100) pct = 100;
if (pct == last) return;
last = pct;
int bar = pct * 30 / 100;
Console.Write("\r" + Label + " [" + new string('=', bar) + new string(' ', 30 - bar) + "] " + pct + "%  ");
}

public void Finish() { done = total; Draw(); Console.WriteLine(); }
}

public abstract class BaseStream : Stream
{
public override bool CanRead { get { return false; } }
public override bool CanSeek { get { return false; } }
public override bool CanWrite { get { return false; } }
public override long Length { get { throw new NotSupportedException(); } }
public override long Position
{
get { throw new NotSupportedException(); }
set { throw new NotSupportedException(); }
}
public override void Flush() { }
public override long Seek(long offset, SeekOrigin origin) { throw new NotSupportedException(); }
public override void SetLength(long value) { throw new NotSupportedException(); }
public override int Read(byte[] buffer, int offset, int count) { throw new NotSupportedException(); }
public override void Write(byte[] buffer, int offset, int count) { throw new NotSupportedException(); }
}
public class NonClosingStream : BaseStream
{
private Stream s;
public NonClosingStream(Stream s) { this.s = s; }
public override bool CanRead { get { return s.CanRead; } }
public override bool CanWrite { get { return s.CanWrite; } }
public override int Read(byte[] b, int o, int c) { return s.Read(b, o, c); }
public override void Write(byte[] b, int o, int c) { s.Write(b, o, c); }
public override void Flush() { s.Flush(); }
}

public class HashWriteStream : BaseStream
{
private Stream inner;
private HashAlgorithm h;
public HashWriteStream(Stream inner, HashAlgorithm h) { this.inner = inner; this.h = h; }
public override bool CanWrite { get { return true; } }
public override void Write(byte[] b, int o, int c) { h.TransformBlock(b, o, c, null, 0); inner.Write(b, o, c); }
public override void Flush() { inner.Flush(); }
public byte[] Final() { h.TransformFinalBlock(new byte[0], 0, 0); return h.Hash; }
}

public class HashReadStream : BaseStream
{
private Stream inner;
private HashAlgorithm h;
public HashReadStream(Stream inner, HashAlgorithm h) { this.inner = inner; this.h = h; }
public override bool CanRead { get { return true; } }
public override int Read(byte[] b, int o, int c)
{
int n = inner.Read(b, o, c);
if (n > 0) h.TransformBlock(b, o, n, null, 0);
return n;
}
public byte[] Final() { h.TransformFinalBlock(new byte[0], 0, 0); return h.Hash; }
}

public class XorStream : BaseStream
{
private Stream inner;
private byte[] key;
private int idx;
private byte[] tmp = new byte[0];

public XorStream(Stream inner, byte[] key) { this.inner = inner; this.key = key; }
public override bool CanRead { get { return inner.CanRead; } }
public override bool CanWrite { get { return inner.CanWrite; } }
public override void Flush() { inner.Flush(); }

public override int Read(byte[] b, int o, int c)
{
int n = inner.Read(b, o, c);
for (int i = 0; i < n; i++)
{
b[o + i] ^= key[idx];
idx++;
if (idx == key.Length) idx = 0;
}
return n;
}

public override void Write(byte[] b, int o, int c)
{
if (tmp.Length < c) tmp = new byte[c];
for (int i = 0; i < c; i++)
{
tmp[i] = (byte)(b[o + i] ^ key[idx]);
idx++;
if (idx == key.Length) idx = 0;
}
inner.Write(tmp, 0, c);
}
}
public class BoundedStream : BaseStream
{
private Stream s;
private long remain;
public BoundedStream(Stream s, long remain) { this.s = s; this.remain = remain; }
public override bool CanRead { get { return true; } }
public override int Read(byte[] b, int o, int c)
{
if (remain <= 0) return 0;
int n = s.Read(b, o, (int)Math.Min((long)c, remain));
remain -= n;
return n;
}
}

public static class Core
{
public const int DefaultIterations = 600000;
public const string XorKeyText = "default_xor_key_for_text_obfuscation_secure_encrypt";
private static readonly byte[] Magic = new byte[] { (byte)'S', (byte)'E', (byte)'v', (byte)'2' };
private const int BufSize = 262144;
public static string LblHash = "Hashing   ";
public static string LblEncode = "Packing   ";
public static string LblVerify = "Verifying ";
public static string LblExtract = "Extracting";
public static string LblKdf = "Deriving key...";
public static string ConflictPrompt = "Already exists: {0}  [O]verwrite all / [R]ename / [S]kip all / [C]ancel:";
public static int ConflictMode = 0; // 0 ask, 1 overwrite, 2 rename, 3 skip
public static string LastSha = "";
public static long LastCount;
public static long LastTotal;
public static long LastOutSize;
public static long LastDataStart;
public static List<string> Skipped = new List<string>();

public static byte[] XorKey()
{
return Encoding.ASCII.GetBytes(XorKeyText);
}

public static string ToHex(byte[] b)
{
StringBuilder sb = new StringBuilder();
for (int i = 0; i < b.Length; i++) sb.Append(b[i].ToString("x2"));
return sb.ToString();
}

internal static bool CompareBytes(byte[] a, byte[] b)
{
if (a.Length != b.Length) return false;
int d = 0;
for (int i = 0; i < a.Length; i++) d |= a[i] ^ b[i];
return d == 0;
}

private static byte[] Rand(int n)
{
byte[] b = new byte[n];
RNGCryptoServiceProvider r = new RNGCryptoServiceProvider();
r.GetBytes(b);
return b;
}

private static int ReadFully(Stream s, byte[] buf, int count)
{
int got = 0;
while (got < count)
{
int n = s.Read(buf, got, count - got);
if (n <= 0) break;
got += n;
}
return got;
}

private static byte[] ReadExact(Stream s, int count)
{
byte[] b = new byte[count];
if (ReadFully(s, b, count) != count) throw new InvalidDataException("FORMAT");
return b;
}

private static char[] SecureChars(SecureString pw)
{
if (pw == null || pw.Length == 0) return new char[0];
char[] c = new char[pw.Length];
IntPtr p = Marshal.SecureStringToGlobalAllocUnicode(pw);
try { Marshal.Copy(p, c, 0, c.Length); }
finally { Marshal.ZeroFreeGlobalAllocUnicode(p); }
return c;
}

public static bool SecureEquals(SecureString a, SecureString b)
{
char[] x = SecureChars(a);
char[] y = SecureChars(b);
bool ok = x.Length == y.Length;
if (ok)
{
int d = 0;
for (int i = 0; i < x.Length; i++) d |= x[i] ^ y[i];
ok = d == 0;
}
Array.Clear(x, 0, x.Length);
Array.Clear(y, 0, y.Length);
return ok;
}
public static int Strength(SecureString pw)
{
char[] c = SecureChars(pw);
int len = c.Length;
bool lo = false, up = false, di = false, ot = false;
for (int i = 0; i < c.Length; i++)
{
if (char.IsLower(c[i])) lo = true;
else if (char.IsUpper(c[i])) up = true;
else if (char.IsDigit(c[i])) di = true;
else ot = true;
}
Array.Clear(c, 0, c.Length);
int classes = (lo ? 1 : 0) + (up ? 1 : 0) + (di ? 1 : 0) + (ot ? 1 : 0);
int score = 0;
if (len >= 8) score++;
if (len >= 12) score++;
if (len >= 16) score++;
if (len >= 20) score++;
if (classes >= 3) score++;
if (classes < 2 && len < 20 && score > 1) score = 1;
if (score > 4) score = 4;
return score;
}

public static byte[] HashFile(string path)
{
SHA256 sha = SHA256.Create();
FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
try
{
byte[] buf = new byte[BufSize];
int n;
while ((n = fs.Read(buf, 0, buf.Length)) > 0) sha.TransformBlock(buf, 0, n, null, 0);
sha.TransformFinalBlock(new byte[0], 0, 0);
return sha.Hash;
}
finally { fs.Close(); }
}
public static byte[] MakeSecret(SecureString pw, string keyFile)
{
char[] chars = SecureChars(pw);
byte[] pwBytes = Encoding.UTF8.GetBytes(chars);
Array.Clear(chars, 0, chars.Length);
byte[] kf = null;
if (!string.IsNullOrEmpty(keyFile)) kf = HashFile(keyFile);
if (pwBytes.Length == 0 && kf == null) return null;
byte[] secret = new byte[pwBytes.Length + (kf == null ? 0 : 32)];
Array.Copy(pwBytes, 0, secret, 0, pwBytes.Length);
if (kf != null) Array.Copy(kf, 0, secret, pwBytes.Length, 32);
Array.Clear(pwBytes, 0, pwBytes.Length);
if (kf != null) Array.Clear(kf, 0, kf.Length);
return secret;
}

private static byte[] Pbkdf2(byte[] pwd, byte[] salt, int iter)
{
HMACSHA256 h = new HMACSHA256(pwd);
try
{
byte[] s = new byte[salt.Length + 4];
Array.Copy(salt, s, salt.Length);
s[salt.Length + 3] = 1;
byte[] u = h.ComputeHash(s);
byte[] t = (byte[])u.Clone();
for (int i = 1; i < iter; i++)
{
u = h.ComputeHash(u);
for (int j = 0; j < t.Length; j++) t[j] ^= u[j];
}
return t;
}
finally { h.Clear(); }
}

private static byte[] Hmac(byte[] key, string label)
{
HMACSHA256 h = new HMACSHA256(key);
try { return h.ComputeHash(Encoding.ASCII.GetBytes(label)); }
finally { h.Clear(); }
}

internal static void DeriveKeys(byte[] secret, byte[] salt, int iter, out byte[] encKey, out byte[] macKey, out byte[] keyCheck)
{
Console.WriteLine(LblKdf);
byte[] master = Pbkdf2(secret, salt, iter);
encKey = Hmac(master, "SE2-ENC");
macKey = Hmac(master, "SE2-MAC");
byte[] kc = Hmac(macKey, "SE2-KEYCHECK");
keyCheck = new byte[16];
Array.Copy(kc, keyCheck, 16);
Array.Clear(master, 0, master.Length);
}

private static RijndaelManaged NewAes(byte[] key, byte[] iv)
{
RijndaelManaged aes = new RijndaelManaged();
aes.KeySize = 256;
aes.BlockSize = 128;
aes.Mode = CipherMode.CBC;
aes.Padding = PaddingMode.PKCS7;
aes.Key = key;
aes.IV = iv;
return aes;
}

private static bool SamePath(string a, string b)
{
return b != null && string.Equals(a, b, StringComparison.OrdinalIgnoreCase);
}

private static void AddDir(string dir, string rel, List<Entry> list, List<string> skipped, string ex1, string ex2)
{
int before = list.Count;
string[] files = new string[0];
try { files = Directory.GetFiles(dir); }
catch { skipped.Add(dir); }
for (int i = 0; i < files.Length; i++)
{
string f = files[i];
if (SamePath(f, ex1) || SamePath(f, ex2)) continue;
try
{
FileInfo fi = new FileInfo(f);
list.Add(new Entry(f, rel + "/" + fi.Name, false, fi.Length,
fi.LastWriteTimeUtc.ToFileTimeUtc(), (int)fi.Attributes & 0x27));
}
catch { skipped.Add(f); }
}
string[] dirs = new string[0];
try { dirs = Directory.GetDirectories(dir); }
catch { skipped.Add(dir); }
for (int i = 0; i < dirs.Length; i++)
{
string d = dirs[i];
string name = Path.GetFileName(d);
if (string.Equals(name, "System Volume Information", StringComparison.OrdinalIgnoreCase) ||
string.Equals(name, "$RECYCLE.BIN", StringComparison.OrdinalIgnoreCase)) continue;
try
{
if ((File.GetAttributes(d) & FileAttributes.ReparsePoint) != 0) { skipped.Add(d); continue; }
}
catch { skipped.Add(d); continue; }
AddDir(d, rel + "/" + name, list, skipped, ex1, ex2);
}
if (list.Count == before)
{
DateTime t = DateTime.UtcNow;
int a = 0;
try { t = Directory.GetLastWriteTimeUtc(dir); a = (int)File.GetAttributes(dir) & 0x27; } catch { }
list.Add(new Entry(dir, rel, true, 0, t.ToFileTimeUtc(), a));
}
}

private static List<Entry> Collect(string[] items, List<string> skipped, string ex1, string ex2)
{
List<Entry> list = new List<Entry>();
for (int i = 0; i < items.Length; i++)
{
string full = Path.GetFullPath(items[i]);
if (Directory.Exists(full))
{
string trimmed = full.TrimEnd('\\');
string name = Path.GetFileName(trimmed);
if (name.Length == 0) name = "Drive_" + full.Substring(0, 1);
AddDir(full, name, list, skipped, ex1, ex2);
}
else
{
FileInfo fi = new FileInfo(full);
list.Add(new Entry(full, fi.Name, false, fi.Length,
fi.LastWriteTimeUtc.ToFileTimeUtc(), (int)fi.Attributes & 0x27));
}
}
return list;
}

private static void WriteContainer(List<Entry> entries, long total, Stream dest, ProgressBar pb)
{
BinaryWriter bw = new BinaryWriter(dest, Encoding.UTF8);
bw.Write(new byte[] { (byte)'S', (byte)'E', (byte)'C', (byte)'1' });
bw.Write(entries.Count);
bw.Write(total);
byte[] buf = new byte[BufSize];
for (int i = 0; i < entries.Count; i++)
{
Entry e = entries[i];
bw.Write((byte)(e.IsDir ? 1 : 0));
bw.Write(e.Rel);
bw.Write(e.MTime);
bw.Write(e.Attr);
if (e.IsDir) continue;
bw.Write(e.Length);
long left = e.Length;
FileStream fs = new FileStream(e.Full, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
try
{
while (left > 0)
{
int n = fs.Read(buf, 0, (int)Math.Min((long)buf.Length, left));
if (n <= 0) throw new IOException("CHANGED");
dest.Write(buf, 0, n);
left -= n;
if (pb != null) pb.Add(n);
}
}
finally { fs.Close(); }
}
bw.Flush();
}
private static byte[] WritePayload(List<Entry> entries, long total, Stream sink, bool gzip, byte[] prefixSha, ProgressBar pb)
{
if (prefixSha != null) sink.Write(prefixSha, 0, prefixSha.Length);
Stream dst = sink;
GZipStream gz = null;
if (gzip) { gz = new GZipStream(sink, CompressionMode.Compress, true); dst = gz; }
HashWriteStream hs = new HashWriteStream(dst, SHA256.Create());
WriteContainer(entries, total, hs, pb);
hs.Flush();
if (gz != null) gz.Close();
return hs.Final();
}
public static void Encode(string[] items, string outPath, string alsoExclude, bool gzip, byte[] secret,
bool usesPassword, bool usesKeyFile, int iterations, bool verify)
{
List<string> skipped = new List<string>();
List<Entry> entries = Collect(items, skipped, outPath, alsoExclude);
Skipped = skipped;
if (entries.Count == 0) throw new InvalidOperationException("EMPTY");
long total = 0;
for (int i = 0; i < entries.Count; i++) total += entries[i].Length;
LastCount = entries.Count;
LastTotal = total;
ProgressBar.Label = LblHash;
ProgressBar pb1 = new ProgressBar(total);
HashWriteStream h1 = new HashWriteStream(Stream.Null, SHA256.Create());
WriteContainer(entries, total, h1, pb1);
byte[] sha = h1.Final();
pb1.Finish();
LastSha = ToHex(sha);

int mode = secret == null ? 1 : 2;
int flags = (gzip ? 1 : 0) | (usesPassword ? 2 : 0) | (usesKeyFile ? 4 : 0);

FileStream fo = new FileStream(outPath, FileMode.Append, FileAccess.Write, FileShare.None);
byte[] sha2;
try
{
LastDataStart = fo.Position;
ProgressBar.Label = LblEncode;
if (mode == 1)
{
fo.Write(Magic, 0, 4);
fo.WriteByte(1);
fo.WriteByte((byte)flags);
fo.Write(sha, 0, 32);
ProgressBar pb2 = new ProgressBar(total);
XorStream xs = new XorStream(new NonClosingStream(fo), XorKey());
sha2 = WritePayload(entries, total, xs, gzip, null, pb2);
xs.Flush();
pb2.Finish();
}
else
{
byte[] salt = Rand(16);
byte[] iv = Rand(16);
byte[] encKey, macKey, kc;
DeriveKeys(secret, salt, iterations, out encKey, out macKey, out kc);
byte[] header = new byte[58];
Array.Copy(Magic, 0, header, 0, 4);
header[4] = 2;
header[5] = (byte)flags;
header[6] = (byte)(iterations & 0xFF);
header[7] = (byte)((iterations >> 8) & 0xFF);
header[8] = (byte)((iterations >> 16) & 0xFF);
header[9] = (byte)((iterations >> 24) & 0xFF);
Array.Copy(salt, 0, header, 10, 16);
Array.Copy(iv, 0, header, 26, 16);
Array.Copy(kc, 0, header, 42, 16);
HMACSHA256 mac = new HMACSHA256(macKey);
HashWriteStream hw = new HashWriteStream(fo, mac);
hw.Write(header, 0, header.Length);
RijndaelManaged aes = NewAes(encKey, iv);
CryptoStream cs = new CryptoStream(new NonClosingStream(hw), aes.CreateEncryptor(), CryptoStreamMode.Write);
ProgressBar pb2 = new ProgressBar(total);
sha2 = WritePayload(entries, total, cs, gzip, sha, pb2);
cs.FlushFinalBlock();
cs.Close();
pb2.Finish();
byte[] tag = hw.Final();
fo.Write(tag, 0, tag.Length);
aes.Clear();
Array.Clear(encKey, 0, encKey.Length);
Array.Clear(macKey, 0, macKey.Length);
}
fo.Flush();
LastOutSize = fo.Length;
}
finally { fo.Close(); }

if (!CompareBytes(sha, sha2)) throw new IOException("CHANGED");

if (verify)
{
ProgressBar.Label = LblVerify;
Archive a = Archive.Open(outPath, LastDataStart);
try
{
if (!a.Unlock(secret)) throw new CryptographicException("VERIFY");
a.Extract(null);
if (!a.ShaOk) throw new CryptographicException("VERIFY");
}
finally { a.Clear(); }
}
}

private static void DeleteFile(string f, bool overwrite)
{
File.SetAttributes(f, FileAttributes.Normal);
if (overwrite)
{
long left = new FileInfo(f).Length;
FileStream fs = new FileStream(f, FileMode.Open, FileAccess.Write, FileShare.None);
try
{
byte[] b = new byte[65536];
RNGCryptoServiceProvider r = new RNGCryptoServiceProvider();
while (left > 0)
{
r.GetBytes(b);
int n = (int)Math.Min((long)b.Length, left);
fs.Write(b, 0, n);
left -= n;
}
fs.Flush();
}
finally { fs.Close(); }
}
File.Delete(f);
}
public static List<string> DeleteFailed = new List<string>();

private static void TryDeleteFile(string f, bool overwrite)
{
try { DeleteFile(f, overwrite); }
catch (Exception ex) { DeleteFailed.Add(f + " : " + ex.Message); }
}

private static void DeleteDir(string d, bool overwrite)
{
string[] files = new string[0];
string[] dirs = new string[0];
try { files = Directory.GetFiles(d); dirs = Directory.GetDirectories(d); }
catch (Exception ex) { DeleteFailed.Add(d + " : " + ex.Message); return; }
for (int i = 0; i < files.Length; i++) TryDeleteFile(files[i], overwrite);
for (int i = 0; i < dirs.Length; i++) DeleteDir(dirs[i], overwrite);
try
{
File.SetAttributes(d, FileAttributes.Normal);
Directory.Delete(d);
}
catch (Exception ex) { DeleteFailed.Add(d + " : " + ex.Message); }
}
public static void DeleteItems(string[] items, bool overwrite)
{
DeleteFailed = new List<string>();
for (int i = 0; i < items.Length; i++)
{
if (Directory.Exists(items[i])) DeleteDir(items[i], overwrite);
else TryDeleteFile(items[i], overwrite);
}
}

private static string SafePath(string root, string rel)
{
string r = rel.Replace('/', '\\');
if (r.Length == 0 || r.IndexOf(':') >= 0 || r[0] == '\\') throw new InvalidDataException("PATH");
string[] parts = r.Split('\\');
for (int i = 0; i < parts.Length; i++)
if (parts[i].Length == 0 || parts[i] == ".." || parts[i] == ".") throw new InvalidDataException("PATH");
string full = Path.GetFullPath(Path.Combine(root, r));
if (!full.StartsWith(root, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("PATH");
return full;
}

private static string UniqueName(string path)
{
string dir = Path.GetDirectoryName(path);
string name = Path.GetFileNameWithoutExtension(path);
string ext = Path.GetExtension(path);
for (int i = 1; ; i++)
{
string cand = Path.Combine(dir, name + " (" + i + ")" + ext);
if (!File.Exists(cand) && !Directory.Exists(cand)) return cand;
}
}

private static int Conflict(string target)
{
if (ConflictMode == 0)
{
Console.WriteLine();
while (true)
{
Console.Write(ConflictPrompt.Replace("{0}", target) + " ");
string a = Console.ReadLine();
if (a == null) throw new OperationCanceledException();
a = a.Trim().ToLowerInvariant();
if (a == "o") ConflictMode = 1;
else if (a == "r") ConflictMode = 2;
else if (a == "s") ConflictMode = 3;
else if (a == "c") throw new OperationCanceledException();
else continue;
break;
}
}
return ConflictMode;
}

internal static void ExtractContainer(Stream s, string destDir, out long count, out long total)
{
BinaryReader br = new BinaryReader(s, Encoding.UTF8);
byte[] m = br.ReadBytes(4);
if (m.Length != 4 || m[0] != 'S' || m[1] != 'E' || m[2] != 'C' || m[3] != '1') throw new InvalidDataException("FORMAT");
int n = br.ReadInt32();
total = br.ReadInt64();
count = n;
if (n < 0 || total < 0) throw new InvalidDataException("FORMAT");

string root = null;
if (destDir != null)
{
root = Path.GetFullPath(destDir);
if (!root.EndsWith("\\")) root += "\\";
Directory.CreateDirectory(root);
}

ProgressBar pb = new ProgressBar(total);
byte[] buf = new byte[BufSize];
for (int i = 0; i < n; i++)
{
int type = br.ReadByte();
string rel = br.ReadString();
long mt = br.ReadInt64();
int attr = br.ReadInt32();
string target = root == null ? null : SafePath(root, rel);

if (type == 1)
{
if (target != null)
{
if (File.Exists(target)) throw new IOException("EXISTS");
Directory.CreateDirectory(target);
}
continue;
}

long len = br.ReadInt64();
if (len < 0) throw new InvalidDataException("FORMAT");
if (target != null && (File.Exists(target) || Directory.Exists(target)))
{
int act = Conflict(target);
if (act == 2) target = UniqueName(target);
else if (act == 3) target = null;
}

FileStream fo = null;
if (target != null)
{
Directory.CreateDirectory(Path.GetDirectoryName(target));
if (File.Exists(target)) File.SetAttributes(target, FileAttributes.Normal);
fo = new FileStream(target, FileMode.Create, FileAccess.Write, FileShare.None);
}
try
{
long left = len;
while (left > 0)
{
int r = s.Read(buf, 0, (int)Math.Min((long)buf.Length, left));
if (r <= 0) throw new InvalidDataException("FORMAT");
if (fo != null) fo.Write(buf, 0, r);
left -= r;
pb.Add(r);
}
}
finally { if (fo != null) fo.Close(); }

if (target != null)
{
try
{
File.SetLastWriteTimeUtc(target, DateTime.FromFileTimeUtc(mt));
File.SetAttributes(target, (FileAttributes)(attr & 0x27));
}
catch { }
}
}
pb.Finish();
}
}

public class Archive
{
public int Mode;
public int Flags;
public int Iterations;
public byte[] HeaderSha;
public bool ShaOk;
public string ShaHex = "";
public long Count;
public long Total;

private string path;
private long dataStart;
private long payloadStart;
private long payloadEnd;
private byte[] salt;
private byte[] iv;
private byte[] keyCheck;
private byte[] encKey;
private byte[] macKey;
public const int MaxIterations = 10000000;
public void Clear()
{
if (encKey != null) Array.Clear(encKey, 0, encKey.Length);
if (macKey != null) Array.Clear(macKey, 0, macKey.Length);
encKey = null;
macKey = null;
}

public bool IsGzip { get { return (Flags & 1) != 0; } }
public bool UsesPassword { get { return (Flags & 2) != 0; } }
public bool UsesKeyFile { get { return (Flags & 4) != 0; } }

public static Archive Open(string path, long dataStart)
{
Archive a = new Archive();
a.path = path;
a.dataStart = dataStart;
FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
try
{
long len = fs.Length;
fs.Position = dataStart;
byte[] h = new byte[6];
if (ReadHeader(fs, h, 6) != 6 || h[0] != 'S' || h[1] != 'E' || h[2] != 'v' || h[3] != '2')
throw new InvalidDataException("FORMAT");
a.Mode = h[4];
a.Flags = h[5];
if (a.Mode == 1)
{
a.HeaderSha = new byte[32];
if (ReadHeader(fs, a.HeaderSha, 32) != 32) throw new InvalidDataException("FORMAT");
a.payloadStart = dataStart + 38;
a.payloadEnd = len;
}
else if (a.Mode == 2)
{
byte[] r = new byte[52];
if (ReadHeader(fs, r, 52) != 52) throw new InvalidDataException("FORMAT");
a.Iterations = r[0] | (r[1] << 8) | (r[2] << 16) | (r[3] << 24);
if (a.Iterations < 1000 || a.Iterations > MaxIterations) throw new InvalidDataException("FORMAT");
a.salt = new byte[16]; Array.Copy(r, 4, a.salt, 0, 16);
a.iv = new byte[16]; Array.Copy(r, 20, a.iv, 0, 16);
a.keyCheck = new byte[16]; Array.Copy(r, 36, a.keyCheck, 0, 16);
a.payloadStart = dataStart + 58;
a.payloadEnd = len - 32;
if (a.payloadEnd < a.payloadStart) throw new InvalidDataException("FORMAT");
}
else throw new InvalidDataException("FORMAT");
}
finally { fs.Close(); }
return a;
}

private static int ReadHeader(Stream s, byte[] b, int count)
{
int got = 0;
while (got < count)
{
int n = s.Read(b, got, count - got);
if (n <= 0) break;
got += n;
}
return got;
}
public bool Unlock(byte[] secret)
{
if (Mode != 2) return true;
byte[] ek, mk, kc;
Core.DeriveKeys(secret, salt, Iterations, out ek, out mk, out kc);
bool ok = Core.CompareBytes(kc, keyCheck);
if (ok) { encKey = ek; macKey = mk; }
else { Array.Clear(ek, 0, ek.Length); Array.Clear(mk, 0, mk.Length); }
return ok;
}
public void Extract(string destDir)
{
FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
try
{
Stream src;
byte[] expected;
if (Mode == 2)
{
if (macKey == null) throw new InvalidOperationException("LOCKED");
ProgressBar.Label = Core.LblVerify;
ProgressBar pbm = new ProgressBar(payloadEnd - dataStart);
HMACSHA256 mac = new HMACSHA256(macKey);
fs.Position = dataStart;
byte[] buf = new byte[262144];
long left = payloadEnd - dataStart;
while (left > 0)
{
int n = fs.Read(buf, 0, (int)Math.Min((long)buf.Length, left));
if (n <= 0) throw new InvalidDataException("FORMAT");
mac.TransformBlock(buf, 0, n, null, 0);
left -= n;
pbm.Add(n);
}
mac.TransformFinalBlock(new byte[0], 0, 0);
pbm.Finish();
byte[] tag = new byte[32];
if (ReadHeader(fs, tag, 32) != 32) throw new InvalidDataException("FORMAT");
if (!Core.CompareBytes(mac.Hash, tag)) throw new CryptographicException("MAC");

fs.Position = payloadStart;
RijndaelManaged aes = new RijndaelManaged();
aes.KeySize = 256;
aes.BlockSize = 128;
aes.Mode = CipherMode.CBC;
aes.Padding = PaddingMode.PKCS7;
aes.Key = encKey;
aes.IV = iv;
CryptoStream cs = new CryptoStream(new BoundedStream(fs, payloadEnd - payloadStart), aes.CreateDecryptor(), CryptoStreamMode.Read);
expected = new byte[32];
if (ReadHeader(cs, expected, 32) != 32) throw new InvalidDataException("FORMAT");
src = cs;
}
else
{
fs.Position = payloadStart;
src = new XorStream(new BoundedStream(fs, payloadEnd - payloadStart), Core.XorKey());
expected = HeaderSha;
}
if (IsGzip) src = new GZipStream(src, CompressionMode.Decompress);

ProgressBar.Label = destDir == null ? Core.LblVerify : Core.LblExtract;
HashReadStream hr = new HashReadStream(src, SHA256.Create());
long count, total;
Core.ExtractContainer(hr, destDir, out count, out total);
Count = count;
Total = total;
byte[] drain = new byte[4096];
while (hr.Read(drain, 0, drain.Length) > 0) { }
byte[] actual = hr.Final();
ShaHex = Core.ToHex(actual);
ShaOk = Core.CompareBytes(actual, expected);
}
finally { fs.Close(); }
}
}
}
'@

$DecSrc = @'
$ErrorActionPreference = 'Stop'
$Self = $env:SE_SELF
$IsTR = ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'tr')
if ($env:SE_LANG) { $IsTR = ($env:SE_LANG -eq 'tr') }

$M_EN = @{
    press      = 'Press any key to exit...'
    compile    = 'The helper code could not be compiled (.NET Framework is required). Details:'
    format     = 'ERROR: Unsupported or damaged file.'
    header     = '================== DECRYPT PROCESS =================='
    file       = 'File       : {0}'
    enc_aes    = 'Protection : AES-256 encrypted'
    enc_none   = 'Protection : none (compressed + obfuscated only)'
    needs      = 'Requires   : {0}'
    n_pw       = 'password'
    n_kf       = 'key file'
    n_both     = 'password + key file'
    t_pw       = 'Password'
    t_kf       = 'Key file (path, drag the file here, or ? to browse)'
    kf_missing = 'Key file not found: {0}'
    kf_pick_title = 'Select the key file'
    kf_pick_fail  = 'The file dialog could not be opened (for example on Server Core). Please type the path instead.'
    wrong      = 'Wrong password or key file ({0}/{1}).'
    conflict   = 'Already exists: {0}|  [O] Overwrite all|  [R] Rename (keep both)|  [S] Skip all|  [C] Cancel|Your choice [O/R/S/C]:'
    lbl_ver    = 'Verifying '
    lbl_ext    = 'Extracting'
    kdf        = 'Deriving key (PBKDF2): verifying password and key file.'
    mac_fail   = 'ERROR: Integrity check FAILED. The file is corrupted or has been modified. Nothing was extracted.'
    cancelled  = 'Cancelled.'
    err        = 'ERROR: {0}'
    done       = 'Done. {0} item(s) extracted to: {1}'
    sha        = 'Calculated SHA256: {0}'
    sha_ok     = 'SHA256: SUCCESS'
    sha_fail   = 'SHA256: FAILED (the data does not match the original)'
    footer     = '================== DECRYPT PROCESS =================='
}

$M_TR = @{
    press      = '\u00c7\u0131k\u0131\u015f i\u00e7in herhangi bir tu\u015fa bas\u0131n...'
    compile    = 'Yard\u0131mc\u0131 kod derlenemedi (.NET Framework gerekli). Ayr\u0131nt\u0131lar:'
    format     = 'HATA: Desteklenmeyen veya bozuk dosya.'
    header     = '================== \u015e\u0130FRE \u00c7\u00d6ZME \u0130\u015eLEM\u0130 =================='
    file       = 'Dosya      : {0}'
    enc_aes    = 'Koruma     : AES-256 ile \u015fifreli'
    enc_none   = 'Koruma     : yok (yaln\u0131zca s\u0131k\u0131\u015ft\u0131r\u0131lm\u0131\u015f + gizlenmi\u015f)'
    needs      = 'Gereken    : {0}'
    n_pw       = 'parola'
    n_kf       = 'anahtar dosyas\u0131'
    n_both     = 'parola + anahtar dosyas\u0131'
    t_pw       = 'Parola'
    t_kf       = 'Anahtar dosyas\u0131 (yol yaz\u0131n, dosyay\u0131 s\u00fcr\u00fckleyin veya ? yaz\u0131p se\u00e7in)'
    kf_missing = 'Anahtar dosyas\u0131 bulunamad\u0131: {0}'
    kf_pick_title = 'Anahtar dosyas\u0131n\u0131 se\u00e7in'
    kf_pick_fail  = 'Dosya se\u00e7me penceresi a\u00e7\u0131lamad\u0131 (\u00f6rne\u011fin Server Core). L\u00fctfen yolu yaz\u0131n.'
    wrong      = 'Parola veya anahtar dosyas\u0131 yanl\u0131\u015f ({0}/{1}).'
    conflict   = 'Zaten var: {0}|  [O] Hepsinin \u00fczerine yaz|  [R] Yeniden adland\u0131r (ikisini de tut)|  [S] Hepsini atla|  [C] \u0130ptal|Se\u00e7iminiz [O/R/S/C]:'
    lbl_ver    = 'Do\u011frulan\u0131yor'
    lbl_ext    = '\u00c7\u0131kar\u0131l\u0131yor '
    kdf        = 'Anahtar t\u00fcretiliyor (PBKDF2): Parola ve anahtar dosyas\u0131 do\u011frulan\u0131yor.'
    mac_fail   = 'HATA: B\u00fct\u00fcnl\u00fck denetimi BA\u015eARISIZ. Dosya bozulmu\u015f veya de\u011fi\u015ftirilmi\u015f. Hi\u00e7bir \u015fey \u00e7\u0131kar\u0131lmad\u0131.'
    cancelled  = '\u0130ptal edildi.'
    err        = 'HATA: {0}'
    done       = 'Tamamland\u0131. {0} \u00f6\u011fe \u015furaya \u00e7\u0131kar\u0131ld\u0131: {1}'
    sha        = 'Hesaplanan SHA256: {0}'
    sha_ok     = 'SHA256: BA\u015eARILI'
    sha_fail   = 'SHA256: BA\u015eARISIZ (veri orijinaliyle e\u015fle\u015fmiyor)'
    footer     = '================== \u015e\u0130FRE \u00c7\u00d6ZME \u0130\u015eLEM\u0130 =================='
}

function T([string]$k) {
    if ($IsTR) { return [regex]::Unescape($M_TR[$k]) }
    return $M_EN[$k]
}

# explicit parameters: `-f $args` misbehaves with 2+ values on PowerShell 2.0
function TF([string]$k, $a0, $a1) {
    return [string]::Format((T $k), $a0, $a1)
}

function Wait-Key {
    Write-Host
    Write-Host (T 'press')
    try { [void][Console]::ReadKey($true) } catch { }
}

# "?" at the key file prompt opens a file dialog. It runs in its own STA PowerShell: Windows PowerShell 2.0
# starts as MTA, which cannot show it, and a failure there (e.g. Server Core) must not break this window.
# Returns the path, '' when cancelled, or $null when the dialog could not be shown.
function Pick-File([string]$title) {
    $out = Join-Path ([IO.Path]::GetTempPath()) ('SE_pick_' + [Guid]::NewGuid().ToString('N') + '.txt')
    $script = @(
        'try {',
        '    Add-Type -AssemblyName System.Windows.Forms',
        '    $owner = New-Object System.Windows.Forms.Form',
        '    $owner.TopMost = $true; $owner.ShowInTaskbar = $false',
        '    $d = New-Object System.Windows.Forms.OpenFileDialog',
        '    $d.Title = $env:SE_PICK_TITLE; $d.CheckFileExists = $true; $d.Filter = "All files|*.*"',
        '    $r = $d.ShowDialog($owner)',
        '    $owner.Dispose()',
        '    if ($r -eq [System.Windows.Forms.DialogResult]::OK) { [IO.File]::WriteAllText($env:SE_PICK_OUT, "OK:" + $d.FileName, [Text.Encoding]::Unicode) }',
        '} catch { [IO.File]::WriteAllText($env:SE_PICK_OUT, "ERR:" + $_.Exception.Message, [Text.Encoding]::Unicode) }'
    ) -join "`r`n"
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
    $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $oldTitle = $env:SE_PICK_TITLE; $oldOut = $env:SE_PICK_OUT
    $env:SE_PICK_TITLE = $title; $env:SE_PICK_OUT = $out
    $result = ''
    try {
        Start-Process -FilePath $psExe -ArgumentList @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $enc) -WindowStyle Hidden -Wait | Out-Null
        if (Test-Path -LiteralPath $out) {
            $txt = [IO.File]::ReadAllText($out, [Text.Encoding]::Unicode)
            if ($txt.StartsWith('OK:')) { $result = $txt.Substring(3) } else { $result = $null }
        }
    } catch {
        $result = $null
    } finally {
        $env:SE_PICK_TITLE = $oldTitle; $env:SE_PICK_OUT = $oldOut
        if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue }
    }
    return $result
}

Write-Host
Write-Host 'SecureEncrypt (AES-256 Encrypt & Decrypt)'
Write-Host
Write-Host 'https://github.com/abdullah-erturk'
Write-Host
Write-Host 'https://erturk-dev.netlify.app'
Write-Host

# csc.exe gets an ANSI command line: a %TEMP% path with characters outside the system code page breaks Add-Type.
# Only in that case the compile uses an ASCII-only folder; %TEMP% is restored right afterwards.
function Add-LibType {
    $oldTemp = $env:TEMP; $oldTmp = $env:TMP
    try {
        if ([IO.Path]::GetTempPath() -match '[^\x00-\x7F]') {
            $cands = @()
            try { $fso = New-Object -ComObject Scripting.FileSystemObject; $cands += $fso.GetFolder([IO.Path]::GetTempPath().TrimEnd('\')).ShortPath } catch { }
            $cands += (Join-Path $env:ProgramData 'SecureEncrypt_tmp')
            $cands += 'C:\Users\Public\SecureEncrypt_tmp'
            $cands += (Join-Path $env:SystemRoot 'Temp')
            foreach ($c in $cands) {
                if (-not $c -or $c -match '[^\x00-\x7F]') { continue }
                try {
                    if (-not (Test-Path -LiteralPath $c)) { New-Item -ItemType Directory -Path $c -Force | Out-Null }
                    $probe = Join-Path $c ('p' + [Guid]::NewGuid().ToString('N') + '.tmp')
                    [IO.File]::WriteAllText($probe, 'x'); Remove-Item -LiteralPath $probe -Force
                    $env:TEMP = $c; $env:TMP = $c
                    break
                } catch { }
            }
        }
        Add-Type -TypeDefinition $LibSrc -Language CSharp
    } finally {
        $env:TEMP = $oldTemp; $env:TMP = $oldTmp
    }
}

try {
    Add-LibType
} catch {
    Write-Host (T 'compile') -ForegroundColor Red
    Write-Host $_.Exception.Message
    Wait-Key
    exit 1
}

[SE.Core]::LblVerify = (T 'lbl_ver')
[SE.Core]::LblExtract = (T 'lbl_ext')
[SE.Core]::LblKdf = (T 'kdf')
[SE.Core]::ConflictPrompt = (T 'conflict').Replace('|', "
")

try {
    # locate the end of the text part (the binary payload follows it)
    $fs = [IO.File]::OpenRead($Self)
    $buf = New-Object byte[] 262144
    $n = $fs.Read($buf, 0, $buf.Length)
    $fs.Close()
    $txt = [Text.Encoding]::GetEncoding(28591).GetString($buf, 0, $n)
    $e = $txt.IndexOf('#PS_' + 'END' + "`r`n")
    if ($e -lt 0) { throw 'FORMAT' }
    $dataStart = [long]($e + 9)

    $arc = [SE.Archive]::Open($Self, $dataStart)

    Write-Host (T 'header')
    Write-Host (TF 'file' (Split-Path -Leaf $Self))

    $secret = $null
    if ($arc.Mode -eq 2) {
        Write-Host (T 'enc_aes')
        if ($arc.UsesPassword -and $arc.UsesKeyFile) { $need = T 'n_both' }
        elseif ($arc.UsesKeyFile) { $need = T 'n_kf' }
        else { $need = T 'n_pw' }
        Write-Host (TF 'needs' $need)
        Write-Host

        $unlocked = $false
        $max = 3
        for ($attempt = 1; $attempt -le $max; $attempt++) {
            $pw = New-Object Security.SecureString
            if ($arc.UsesPassword) { $pw = Read-Host -AsSecureString (T 't_pw') }
            $kf = $null
            if ($arc.UsesKeyFile) {
                while ($true) {
                    $k = (Read-Host (T 't_kf')).Trim().Trim('"')
                    if ($k -eq '?') {
                        $picked = Pick-File (T 'kf_pick_title')
                        if ($picked -eq $null) { Write-Host (T 'kf_pick_fail') -ForegroundColor Yellow; continue }
                        if ($picked.Length -eq 0) { continue }
                        $k = $picked
                    }
                    if ($k.Length -gt 0 -and (Test-Path -LiteralPath $k -PathType Leaf)) { $kf = [IO.Path]::GetFullPath($k); break }
                    Write-Host (TF 'kf_missing' $k) -ForegroundColor Red
                }
            }
            $secret = [SE.Core]::MakeSecret($pw, $kf)
            if ($secret -ne $null -and $arc.Unlock($secret)) { $unlocked = $true; break }
            if ($secret -ne $null) { [Array]::Clear($secret, 0, $secret.Length) }
            Write-Host (TF 'wrong' $attempt $max) -ForegroundColor Red
            if ($attempt -lt $max) { Start-Sleep -Seconds 1 }
        }
        if (-not $unlocked) { Wait-Key; exit 1 }
    } else {
        Write-Host (T 'enc_none')
    }

    Write-Host
    # extract next to the .cmd file that was started
    $dest = Split-Path -Parent $Self
    Write-Host


    try { $arc.Extract($dest) }
    finally {
        $arc.Clear()
        if ($secret -ne $null) { [Array]::Clear($secret, 0, $secret.Length) }
    }

    Write-Host
    Write-Host (TF 'sha' $arc.ShaHex)
    if ($arc.ShaOk) { Write-Host (T 'sha_ok') -ForegroundColor Green }
    else { Write-Host (T 'sha_fail') -ForegroundColor Red }
    $cnt = [string]$arc.Count
    $fullDest = [IO.Path]::GetFullPath($dest)
    Write-Host (TF 'done' $cnt $fullDest)
    Write-Host (T 'footer')
    Wait-Key
    if ($arc.ShaOk) { exit 0 } else { exit 1 }
} catch {
    $ex = $_.Exception
    if ($ex.InnerException -ne $null) { $ex = $ex.InnerException }
    Write-Host
    if ($ex -is [System.Security.Cryptography.CryptographicException]) { Write-Host (T 'mac_fail') -ForegroundColor Red }
    elseif ($ex -is [OperationCanceledException]) { Write-Host (T 'cancelled') -ForegroundColor Yellow }
    elseif ($ex.Message -eq 'FORMAT') { Write-Host (T 'format') -ForegroundColor Red }
    else { Write-Host (TF 'err' $ex.Message) -ForegroundColor Red }
    Wait-Key
    exit 1
}
'@

$StubSrc = @'
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
'@

$ShimSrc = @'
// SecureEncrypt right-click helper.
// Explorer starts one process per selected item. Instead of guessing how long the others take,
// the first thing each instance does is ask Explorer which items are selected in the window the
// clicked item is in. All instances of one selection compute the same key; the first one takes
// the lock and starts ONE visible SecureEncrypt window with the whole selection, the others quit.
// Without a usable Explorer selection (desktop, search results, ...) the older queue method is used:
// the instances queue their paths, the leader waits until nothing new arrives, and the window merges
// stragglers via /late while the user types the password.
var sh = new ActiveXObject("WScript.Shell");
var fso = new ActiveXObject("Scripting.FileSystemObject");

if (WScript.Arguments.length < 1) { WScript.Quit(1); }

var QUIET = 1500;          // ms without a new item before the first window is started (queue method)
var MAXWAIT = 15000;       // ms, upper limit for the quiet wait (queue method)
var LINGER = 90000;        // ms the helper waits for the window to take over before it cleans up (queue method)
var STALE = 120000;        // ms after which a lock file left behind is ignored
var SELLOCK = 20000;       // ms the selection lock is held, so late instances of the same selection quit
try {
    var ev = sh.Environment("Process")("SE_SHIM_LINGER_MS");
    if (ev && ev.length > 0) { LINGER = parseInt(ev, 10); }
    var ev2 = sh.Environment("Process")("SE_SHIM_SELLOCK_MS");
    if (ev2 && ev2.length > 0) { SELLOCK = parseInt(ev2, 10); }
} catch (e0) { }

var target = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "SecureEncrypt.cmd");
var q = fso.BuildPath(sh.ExpandEnvironmentStrings("%TEMP%"), "SecureEncrypt_queue");
if (!fso.FolderExists(q)) { try { fso.CreateFolder(q); } catch (e1) { } }

function norm(p) {
    var s = String(p).toLowerCase();
    while (s.length > 3 && s.charAt(s.length - 1) == "\\") { s = s.substring(0, s.length - 1); }
    return s;
}

// One visible window with all paths; late = look for stragglers.
// The paths travel in a small Unicode list file (/list), not on the command line: a %VARIABLE% pattern inside
// a file name would be expanded by the command interpreter.
function launch(list, late) {
    list.sort();
    var listFile = fso.BuildPath(q, "list_" + new Date().getTime() + "_" + Math.floor(Math.random() * 1000000) + ".txt");
    var lf = fso.CreateTextFile(listFile, true, true);
    lf.Write(list.join("\r\n"));
    lf.Close();
    sh.Run('"' + target + '"' + (late ? " /late" : "") + ' /list "' + listFile + '"', 1, false);
}

// ---------------------------------------------------------------- selection method

// Paths of the selection of the Explorer window that contains 'clicked', or null.
function getSelection(clicked) {
    try {
        var shell = new ActiveXObject("Shell.Application");
        var wins = shell.Windows();
        var want = norm(clicked);
        for (var i = 0; i < wins.Count; i++) {
            var w = null;
            try { w = wins.Item(i); } catch (e2) { continue; }
            if (w == null) { continue; }
            var items = null;
            try { items = w.Document.SelectedItems(); } catch (e3) { continue; }
            if (items == null || items.Count < 1) { continue; }
            var paths = [];
            var found = false;
            for (var k = 0; k < items.Count; k++) {
                var pth = "";
                try { pth = items.Item(k).Path; } catch (e4) { }
                if (pth && pth.length > 0) {
                    paths.push(pth);
                    if (norm(pth) == want) { found = true; }
                }
            }
            if (found) { return paths; }
        }
    } catch (e5) { }
    return null;
}

function selectionKey(paths) {
    var a = [];
    for (var i = 0; i < paths.length; i++) { a.push(norm(paths[i])); }
    a.sort();
    var s = a.join("|");
    var h = 5381;
    for (var j = 0; j < s.length; j++) { h = ((h * 33) ^ s.charCodeAt(j)) & 0x7fffffff; }
    return h.toString(16) + "_" + a.length;
}

function cleanSelectionLocks() {
    try {
        var en = new Enumerator(fso.GetFolder(q).Files);
        for (; !en.atEnd(); en.moveNext()) {
            var file = en.item();
            if (!/^sel_.*\.lock$/i.test(file.Name)) { continue; }
            var old = true;
            try {
                var r = fso.OpenTextFile(file.Path, 1, false);
                var stamp = parseInt(r.ReadAll(), 10);
                r.Close();
                if (!isNaN(stamp) && (new Date().getTime() - stamp) < STALE) { old = false; }
            } catch (e6) { }
            if (old) { try { fso.DeleteFile(file.Path, true); } catch (e7) { } }
        }
    } catch (e8) { }
}

// milliseconds since the lock file was written (a very large number when it cannot be read)
function lockAge(path) {
    try {
        var r = fso.OpenTextFile(path, 1, false);
        var stamp = parseInt(r.ReadAll(), 10);
        r.Close();
        if (!isNaN(stamp)) { return new Date().getTime() - stamp; }
    } catch (e10) { }
    return 1e12;
}

// The lock file is left behind on purpose: the other instances of the same selection start within a moment and
// see it (younger than SELLOCK) and quit. Once it is older than SELLOCK the same selection can be used again.
function runWithSelection(sel) {
    cleanSelectionLocks();
    var lockPath = fso.BuildPath(q, "sel_" + selectionKey(sel) + ".lock");
    if (fso.FileExists(lockPath)) {
        if (lockAge(lockPath) < SELLOCK) { return; }
        try { fso.DeleteFile(lockPath, true); } catch (e11) { return; }
    }
    try {
        var l = fso.CreateTextFile(lockPath, false);
        l.Write(String(new Date().getTime()));
        l.Close();
    } catch (e9) { return; }          // another instance of this very selection already started the window
    launch(sel, false);
}

var selection = getSelection(WScript.Arguments(0));
if (selection != null && selection.length > 0) {
    runWithSelection(selection);
    WScript.Quit(0);
}

// ---------------------------------------------------------------- queue method (fallback)

// 1) queue my path (write to .tmp, rename when complete so the leader never reads a half written file)
var id = new Date().getTime() + "_" + Math.floor(Math.random() * 1000000);
var tmp = fso.BuildPath(q, id + ".tmp");
var f = fso.CreateTextFile(tmp, true, true);
f.Write(WScript.Arguments(0));
f.Close();
fso.MoveFile(tmp, fso.BuildPath(q, id + ".txt"));

// 2) leader election: only one instance can create the lock file.
//    The lock holds its own creation time, so no file date conversion is needed to detect a stale lock.
var lock = fso.BuildPath(q, "leader.lock");
var leader = false;
for (var attempt = 0; attempt < 2 && !leader; attempt++) {
    try {
        var l2 = fso.CreateTextFile(lock, false);
        l2.Write(String(new Date().getTime()));
        l2.Close();
        leader = true;
    } catch (e11) {
        var stale = false;
        try {
            var r2 = fso.OpenTextFile(lock, 1, false);
            var stamp2 = parseInt(r2.ReadAll(), 10);
            r2.Close();
            if (!isNaN(stamp2) && (new Date().getTime() - stamp2) > STALE) { stale = true; }
        } catch (e12) { }
        if (stale) { try { fso.DeleteFile(lock, true); } catch (e13) { } } else { break; }
    }
}
if (!leader) { WScript.Quit(0); }

function queued() {
    var n = 0;
    var en = new Enumerator(fso.GetFolder(q).Files);
    for (; !en.atEnd(); en.moveNext()) { if (/\.txt$/i.test(en.item().Name)) { n++; } }
    return n;
}

// moves all queued paths into 'list' (and removes them from the queue)
function collect(list) {
    var en = new Enumerator(fso.GetFolder(q).Files);
    for (; !en.atEnd(); en.moveNext()) {
        var file = en.item();
        if (!/\.txt$/i.test(file.Name)) { continue; }
        var p = "";
        try {
            var t = fso.OpenTextFile(file.Path, 1, false, -1);
            p = t.ReadAll();
            t.Close();
            fso.DeleteFile(file.Path, true);
        } catch (e14) { continue; }
        var dup = false;
        for (var i = 0; i < list.length; i++) { if (list[i].toLowerCase() == p.toLowerCase()) { dup = true; } }
        if (p.length > 0 && !dup) { list.push(p); }
    }
}

// 3) wait until no new item has arrived for QUIET ms (slow machines start the instances late)
var lastCount = queued();
var quiet = 0;
var waited = 0;
while (quiet < QUIET && waited < MAXWAIT) {
    WScript.Sleep(250);
    waited += 250;
    var now = queued();
    if (now != lastCount) { lastCount = now; quiet = 0; } else { quiet += 250; }
}
var first = [];
collect(first);
if (first.length > 0) { launch(first, true); }

// 4) the window removes the lock when it has merged the stragglers; wait for that
var t0 = new Date().getTime();
while (fso.FileExists(lock) && (new Date().getTime() - t0) < LINGER) { WScript.Sleep(250); }
if (fso.FileExists(lock)) {
    // the window did not take over in time: release the lock and give the leftovers a window of their own
    var rest = [];
    collect(rest);
    try { fso.DeleteFile(lock, true); } catch (e15) { }
    collect(rest);
    if (rest.length > 0) { launch(rest, true); }
}
'@


# ---------------------------------------------------------------- entry point

function Run-Main($argList) {
    $a = @($argList)
    $queue = $false
    $late = $false
    while ($a.Count -gt 0 -and ($a[0] -eq '/q' -or $a[0] -eq '/late')) {
        if ($a[0] -eq '/q') { $queue = $true } else { $late = $true }
        if ($a.Count -gt 1) { $a = @($a[1..($a.Count - 1)]) } else { $a = @() }
    }
    # the right-click helper passes the paths in a Unicode list file (file names may contain %VARIABLE% patterns)
    if ($a.Count -ge 2 -and $a[0] -eq '/list') {
        $listFile = $a[1]
        $lines = @()
        try { $lines = [IO.File]::ReadAllLines($listFile, [Text.Encoding]::Unicode) }
        finally { try { Remove-Item -LiteralPath $listFile -Force } catch { } }
        $a = @($lines | Where-Object { $_.Trim().Length -gt 0 })
    }
    if ($a.Count -eq 0) { Show-InstallMenu; return }
    if ($queue) { $a = @(Wait-Queue $a[0]) }
    try {
        Invoke-Encrypt ([string[]]$a) $late
    } finally {
        if ($late) { Remove-LeaderLock }
    }
}

try {
    Run-Main $args
} catch {
    Write-Host
    Write-Host (TF 'err' $_.Exception.Message) -ForegroundColor Red
    Wait-Key
    exit 1
}
