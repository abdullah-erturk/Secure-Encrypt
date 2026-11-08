@echo off
title SecureEncrypt (AES-256 Encrypt ^& Decrypt^) by Abdullah ERTURK
set "_V_SIG=2d3b7fbaf9f876db0d70bd32e45a8c637e08b9dbb009f68b0b27b39bafaad588"
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
more +77 "%~f0" > "%SE_PS%" 2>nul
if not exist "%SE_PS%" (
    echo ERROR: Could not extract the program. Windows PowerShell is required.
    pause
    exit /b 1
)
:: Window mode: PowerShell is started hidden and detached and this console window closes at once. (On Windows 11 the
:: console is a Windows Terminal window; it would stay open behind the program's own window.)
:: The text mode (SE_GUI=0, /console, /q, /elevated) keeps the console and waits for the program.
set "SE_DETACH=1"
if "%SE_GUI%"=="0" set "SE_DETACH="
for %%A in (%*) do (
    if /i "%%~A"=="/console" set "SE_DETACH="
    if /i "%%~A"=="/q" set "SE_DETACH="
    if /i "%%~A"=="/elevated" set "SE_DETACH="
)
if defined SE_DETACH (
    set "SE_DETACHED=1"
    start "" /min powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SE_PS%" %*
    exit /b 0
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SE_PS%" %*
set "SE_RC=%ERRORLEVEL%"
del /f /q "%SE_PS%" >nul 2>&1
exit /b %SE_RC%
#@@PS
$ErrorActionPreference = 'Stop'
$SelfPath = $env:SE_SELF
# Started hidden and detached by the launcher: nobody deletes the extracted copy of this script afterwards, so it removes
# itself (PowerShell has read the whole file by now).
if ($env:SE_DETACHED -eq '1') { try { Remove-Item -LiteralPath $MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue } catch { } }
$script:RunItems = @()
$Version = '7.0'
# ---------------------------------------------------------------- texts
# The texts live in src\lang\*.ini; build.ps1 embeds them as $LangData (language code -> key -> text).
# Keys that a language lacks fall back to English. The same block is in engine.ps1 and dec.ps1.

$script:LangCode = 'en'

# order: SE_LANG, the language chosen in the window (saved), the Windows display language, English
function Get-LangCode {
    $c = $env:SE_LANG
    if (-not $c) {
        try {
            $rk = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\SecureEncrypt')
            if ($rk -ne $null) { $c = [string]$rk.GetValue('Language'); $rk.Close() }
        } catch { }
    }
    if (-not $c) { $c = [Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName }
    $c = ([string]$c).ToLower()
    if ($LangData.ContainsKey($c)) { return $c }
    return 'en'
}

function Set-Language([string]$code) {
    if (-not $LangData.ContainsKey($code)) { return }
    $script:LangCode = $code
    try {
        $rk = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\SecureEncrypt')
        $rk.SetValue('Language', $code)
        $rk.Close()
    } catch { }
}

function T([string]$k) {
    $v = $null
    if ($LangData.ContainsKey($script:LangCode)) { $v = $LangData[$script:LangCode][$k] }
    if ($v -eq $null) { $v = $LangData['en'][$k] }
    if ($v -eq $null) { return $k }
    return [regex]::Unescape($v)
}

# hands the texts and the language list to the window code (C#)
function Push-GuiStrings {
    foreach ($k in @($LangData['en'].Keys)) { [SE.UI.Ui]::Put($k, (T $k)) }
    $codes = @($LangData.Keys | Sort-Object)
    $names = @()
    foreach ($c in $codes) {
        $n = $LangData[$c]['lang_name']
        if ($n -eq $null) { $n = $c }
        $names += [regex]::Unescape($n)
    }
    [SE.UI.Ui]::SetLanguages([string[]]$codes, [string[]]$names, $script:LangCode)
}

# explicit parameters: `-f $args` misbehaves with 2+ values on PowerShell 2.0
function TF([string]$k, $a0, $a1) {
    return [string]::Format((T $k), $a0, $a1)
}

# ---------------------------------------------------------------- helpers

$CompressedExt = @('.zip', '.7z', '.rar', '.gz', '.bz2', '.xz', '.cab', '.jpg', '.jpeg', '.png', '.gif', '.webp',
    '.mp3', '.aac', '.ogg', '.flac', '.mp4', '.mkv', '.avi', '.mov', '.webm', '.wmv', '.docx', '.xlsx', '.pptx',
    '.odt', '.ods', '.odp', '.apk', '.jar', '.msi', '.iso', '.pdf')

# A hidden (detached) run has no console to talk to: the text mode is shown in a new, visible console instead.
function Restart-Visible([string[]]$items) {
    $env:SE_GUI = '0'
    $env:SE_DETACHED = ''
    $q = ''
    foreach ($x in $items) { if ($x) { $q += ' "' + $x + '"' } }
    Start-Process -FilePath $env:ComSpec -ArgumentList ('/c ""' + $SelfPath + '"' + $q + '"')
}

function Wait-Key {
    if ($env:SE_DETACHED -eq '1') { Restart-Visible $script:RunItems; exit 1 }
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
$script:LibLoaded = $false

function Add-LibType([bool]$gui) {
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
        if ($gui) {
            Add-Type -TypeDefinition ($LibSrc + "`r`n" + $GuiSrc) -Language CSharp -ReferencedAssemblies 'System.Windows.Forms.dll', 'System.Drawing.dll'
        } else {
            Add-Type -TypeDefinition $LibSrc -Language CSharp
        }
    } finally {
        $env:TEMP = $oldTemp; $env:TMP = $oldTmp
    }
}

function Ensure-Lib([bool]$gui) {
    try {
        if (-not $script:LibLoaded) { Add-LibType $gui; $script:LibLoaded = $true }
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
    if ($gui -and $script:LibLoaded) {
        [SE.UI.Ui]::CompressedExt = [string[]]$CompressedExt
    }
}

# The window (GUI) mode needs Windows Forms, which Server Core does not have.
function Test-GuiAvailable {
    try {
        if (-not [Environment]::UserInteractive) { return $false }
        return ([Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') -ne $null)
    } catch { return $false }
}

# text part of every *_decrypt.cmd: batch stub + the decoder program
function Get-HeadText {
    $decPs = $LangDecSrc + "`r`n" + '$LibSrc = @' + "'" + "`r`n" + $LibSrc + "`r`n" + "'@" + "`r`n" + '$GuiSrc = @' + "'" + "`r`n" + $GuiSrc + "`r`n" + "'@" + "`r`n" + $DecSrc
    $head = $StubSrc + "`r`n" + '#PS_' + "BEGIN`r`n" + $decPs + "`r`n" + '#PS_' + "END`r`n"
    if ($head -cmatch '[^\x00-\x7F]') { throw 'internal: non-ASCII header' }
    return $head
}

function Invoke-EncryptGui([string[]]$paths, [bool]$late) {
    Ensure-Lib $true
    $head = Get-HeadText
    $items = New-Object System.Collections.ArrayList
    foreach ($p in $paths) {
        $p = $p.Trim().Trim('"')
        if ($p.Length -eq 0 -or -not (Test-Path -LiteralPath $p)) { continue }
        [void]$items.Add([IO.Path]::GetFullPath($p))
    }
    # right-click fallback (queue method): the helper waited until nothing new arrived; merge what was queued since
    if ($late) {
        foreach ($lp in (Get-LateItems)) {
            if ($lp -and (Test-Path -LiteralPath $lp)) {
                $lf = [IO.Path]::GetFullPath($lp)
                if ($items -notcontains $lf) { [void]$items.Add($lf) }
            }
        }
        Remove-LeaderLock
    }
    $script:GuiItems = [string[]]$items.ToArray([string])
    # choosing another language in the window closes it; it is shown again in that language with the same items
    while ($true) {
        Push-GuiStrings
        $rc = [SE.UI.Ui]::Encrypt([string[]]$items.ToArray([string]), $head)
        $req = [SE.UI.Ui]::LangRequest
        if ($req) {
            Set-Language $req
            [SE.UI.Ui]::LangRequest = ''
            $items = New-Object System.Collections.ArrayList
            foreach ($k in [SE.UI.Ui]::KeptItems) { [void]$items.Add($k) }
            continue
        }
        exit $rc
    }
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

# ---------------------------------------------------------------- Windows 11 context menu entry (optional, experimental)
# The new Windows 11 context menu only lists entries of apps that have a package identity. This registers a small
# UNSIGNED sparse package (Windows' test path, Add-AppxPackage -AllowUnsigned) whose COM server (compiled here from
# the embedded source) provides the "SecureEncrypt" entry. Needs administrator rights; undone by Remove-ModernMenu.

function Test-ModernMenuSupported {
    try {
        if ([Environment]::OSVersion.Version.Build -lt 22621) { return $false }
        $c = Get-Command Add-AppxPackage -ErrorAction Stop
        return [bool]$c.Parameters.ContainsKey('AllowUnsigned')
    } catch { return $false }
}

function Test-ModernMenuInstalled {
    try { return (@(Get-AppxPackage -Name 'AbdullahErturk.SecureEncrypt' -ErrorAction Stop).Count -gt 0) } catch { return $false }
}

function Remove-ModernMenu {
    Get-Process -Name SecureEncryptShell -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Get-AppxPackage -Name 'AbdullahErturk.SecureEncrypt' -AllUsers -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath (Join-Path $env:ProgramFiles 'SecureEncrypt') -Recurse -Force -ErrorAction SilentlyContinue
}

function Add-ModernMenu {
    $dir = Join-Path $env:ProgramFiles 'SecureEncrypt'
    $work = Join-Path ([IO.Path]::GetTempPath()) ('SecureEncrypt_menu_' + [Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($work)
    try {
        Remove-ModernMenu
        [void][IO.Directory]::CreateDirectory($dir)
        # the COM server
        $srcFile = Join-Path $work 'shell_server.cs'
        [IO.File]::WriteAllText($srcFile, $ShellSrc, [Text.Encoding]::ASCII)
        $csc = Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'csc.exe'
        $exe = Join-Path $dir 'SecureEncryptShell.exe'
        # icon file (also the icon of the exe) and the package
        Add-Type -TypeDefinition $PackSrc -Language CSharp -ReferencedAssemblies 'System.Drawing.dll'
        $ico = Join-Path $dir 'SecureEncrypt.ico'
        [ShellPack]::WriteIco($ico)
        # application manifest: runs as the calling user, no elevation, Windows 7 - 11
        $mf = Join-Path $work 'app.manifest'
        $mfText = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' + "`r`n" +
            '<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">' + "`r`n" +
            '  <assemblyIdentity version="7.0.0.0" processorArchitecture="*" name="SecureEncrypt.ShellServer" type="win32" />' + "`r`n" +
            '  <description>SecureEncrypt Windows 11 context menu handler</description>' + "`r`n" +
            '  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3"><security><requestedPrivileges><requestedExecutionLevel level="asInvoker" uiAccess="false" /></requestedPrivileges></security></trustInfo>' + "`r`n" +
            '  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1"><application>' + "`r`n" +
            '    <supportedOS Id="{35138b9a-5d96-4fbd-8e2d-a2440225f93a}" />' + "`r`n" +
            '    <supportedOS Id="{e2011457-1546-43c5-a5fe-008deee3d3f0}" />' + "`r`n" +
            '    <supportedOS Id="{4a2f28e3-53b9-4441-ba9c-d69d4a4a6e38}" />' + "`r`n" +
            '    <supportedOS Id="{1f676c76-80e1-4239-95bb-83d0f6d0da78}" />' + "`r`n" +
            '    <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}" />' + "`r`n" +
            '  </application></compatibility>' + "`r`n" +
            '</assembly>'
        [IO.File]::WriteAllText($mf, $mfText, (New-Object Text.UTF8Encoding($false)))
        $out = & $csc /nologo /target:winexe /optimize+ /out:"$exe" /win32icon:"$ico" /win32manifest:"$mf" "$srcFile"
        if ($LASTEXITCODE -ne 0) { throw ('The menu server could not be compiled: ' + ($out -join ' ')) }
        $msix = [ShellPack]::Build($work, $ManifestSrc)
        # the entry names, in the current language
        [IO.File]::WriteAllLines((Join-Path $dir 'labels.txt'), @((T 'menu_encrypt'), (T 'menu_dec'), (T 'menu_open')), (New-Object Text.UTF8Encoding($false)))
        Add-AppxPackage -Path $msix -ExternalLocation $dir -AllowUnsigned -ErrorAction Stop
        [ShellPack]::NotifyShell()
    } finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Do-Uninstall([string]$target) {    Write-Host
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
    try { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree('Software\SecureEncrypt') } catch { }
    if (Test-ModernMenuSupported) { try { Remove-ModernMenu } catch { } }
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
    if (Test-ModernMenuSupported) {
        try { Add-ModernMenu } catch { Write-Host (TF 'err' $_.Exception.Message) -ForegroundColor Yellow }
    }
    Write-Host
    Write-Host (T 'install_ok') -ForegroundColor Green
    Write-Host (T 'install_menu')
}

# Install window. The window only asks; the work (registry, files) is done here and the window is shown
# again with the result, because PowerShell 2.0 cannot run script code on the window's own thread.
# Install / uninstall from the window. The window itself runs with normal rights; only this step needs an
# administrator: it starts the same file elevated (UAC) with "/elevated install|uninstall" and waits for it.
# Returns @(message, ok).
function Invoke-SetupAction([string]$what, [string]$target) {
    try {
        if (Test-Admin) {
            if ($what -eq 'install') { Do-Install $target }
            else { Do-Uninstall $target }
        } else {
            $p = Start-Process -FilePath $SelfPath -ArgumentList @('/elevated', $what) -Verb RunAs -PassThru -Wait
        }
    } catch {
        return @((T 'admin_denied'), $false)
    }
    $now = Test-Path -LiteralPath $target
    if ($what -eq 'install' -and $now) {
        # the entry of the new Windows 11 menu is part of the install; say so when it could not be added
        if ((Test-ModernMenuSupported) -and -not (Test-ModernMenuInstalled)) { return @(((T 'install_ok') + ' ' + (T 'g_modern_skipped')), $true) }
        return @((T 'install_ok'), $true)
    }
    if ($what -eq 'uninstall' -and -not $now) { return @((T 'uninstall_ok'), $true) }
    return @((T 'g_setup_fail'), $false)
}

function Show-InstallGui {
    Ensure-Lib $true
    $target = Join-Path $env:SystemRoot 'SecureEncrypt.cmd'
    $msg = ''
    $ok = $true
    while ($true) {
        $installed = Test-Path -LiteralPath $target
        Push-GuiStrings
        $act = [SE.UI.Ui]::Setup($installed, $msg, $ok)
        $req = [SE.UI.Ui]::LangRequest
        if ($req) { Set-Language $req; [SE.UI.Ui]::LangRequest = ''; $msg = ''; continue }
        if ($act -eq 1) {
            $r = Invoke-SetupAction 'install' $target
            $msg = $r[0]; $ok = $r[1]
        } elseif ($act -eq 2) {
            $r = Invoke-SetupAction 'uninstall' $target
            $msg = $r[0]; $ok = $r[1]
        } elseif ($act -eq 3) {
            # use without installing: the encrypt window (this process keeps its normal rights, so drag and drop works)
            Invoke-EncryptGui @() $false
            break
        } else {
            break
        }
    }
}

function Show-InstallMenu([bool]$useGui) {
    # the window runs with normal rights (it can also be used without installing); the text part below needs them from the start
    if ($useGui) { Show-InstallGui; return }
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
    $refused = New-Object System.Collections.ArrayList
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
        if (Test-Forbidden $full) { [void]$refused.Add($full); continue }
        if ($items -notcontains $full) { [void]$items.Add($full) }
    }
    # system locations are reported once, together; the rest of the selection is still processed
    if ($refused.Count -gt 0) {
        Write-Host (T 'warning')
        Write-Host
        foreach ($r in $refused) { Write-Host $r }
        Write-Host
        Write-Host (T 'forbidden')
        if ($items.Count -eq 0) { Wait-Key; exit 1 }
        Write-Host
    }
    if ($items.Count -eq 0) { Write-Host (T 'empty') -ForegroundColor Red; Wait-Key; exit 1 }

    Ensure-Lib $false

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
    $head = Get-HeadText
    [IO.File]::WriteAllText($part, $head, [Text.Encoding]::ASCII)

    $gzip = $true
    if ($items.Count -eq 1 -and (Test-Path -LiteralPath $first -PathType Leaf)) {
        if ($CompressedExt -contains [IO.Path]::GetExtension($first).ToLower()) { $gzip = $false }
    }
    # very large data: the GZip component of older .NET versions cannot handle more than 4 GB
    if ($gzip -and [SE.Core]::TotalSize([string[]]$items.ToArray([string]), [SE.Core]::GzipLimit) -ge [SE.Core]::GzipLimit) { $gzip = $false }

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
    if ([SE.Core]::LastOutSize -ge 4294967296) { Write-Host (T 'big_warn') -ForegroundColor Yellow }
    $ts = $sw.Elapsed
    $uh = T 'unit_h'; $um = T 'unit_m'; $us = T 'unit_s'
    if ($ts.TotalSeconds -lt 60) { $tt = ('{0:F2} {1}' -f $ts.TotalSeconds, $us) }
    else {
        $tot = [long][math]::Round($ts.TotalSeconds)
        $hh = [math]::Floor($tot / 3600); $mm = [math]::Floor(($tot % 3600) / 60); $ss = $tot % 60
        if ($hh -gt 0) { $tt = ('{0} {1} {2} {3} {4} {5}' -f $hh, $uh, $mm, $um, $ss, $us) } else { $tt = ('{0} {1} {2} {3}' -f $mm, $um, $ss, $us) }
    }
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

$LangData = @{
    'de' = @{
        'admin_denied' = 'Administratorrechte wurden nicht erteilt.'
        'big_warn' = 'HINWEIS: Die Datei ist gr\u00f6\u00dfer als 4 GB; sie kann unter Windows nicht durch einen Doppelklick ge\u00f6ffnet werden. Um sie zu entschl\u00fcsseln, klicken Sie mit der rechten Maustaste darauf.'
        'cancelled' = 'Abgebrochen.'
        'changed' = 'Eine Quelldatei wurde w\u00e4hrend der Verarbeitung ge\u00e4ndert. Bitte versuchen Sie es erneut.'
        'choice' = 'Ihre Wahl [1/2/3] (Zahl eingeben und ENTER dr\u00fccken)'
        'comp_off' = 'nicht komprimiert (bereits komprimiertes Format oder sehr gro\u00dfe Datenmenge)'
        'comp_on' = 'GZip-komprimiert'
        'compile' = 'Der Hilfscode konnte nicht kompiliert werden (.NET Framework erforderlich). Details:'
        'del_fail' = 'Konnte nicht alle Originale l\u00f6schen: {0}'
        'del_ok' = 'Originalelement(e) gel\u00f6scht.'
        'del_partial' = 'Einige Originale konnten NICHT gel\u00f6scht werden ({0}); Der Rest wurde gel\u00f6scht:'
        'del_partial_hint' = 'Die verschl\u00fcsselte Kopie ist vollst\u00e4ndig. Schlie\u00dfen Sie alle Programme, die auf diese Dateien zugreifen, und l\u00f6schen Sie die Dateien anschlie\u00dfend manuell.'
        'del_skip' = 'Originale wurden NICHT gel\u00f6scht (das Ziel befindet sich innerhalb eines Quellordners, oder einige Elemente wurden \u00fcbersprungen).'
        'done' = 'Fertig. {0} Element(e) extrahiert nach: {1}'
        'dont_forget' = 'WICHTIG: VERGESSEN SIE NICHT IHR PASSWORT / IHRE SCHL\u00dcSSELDATEI. Ohne diese k\u00f6nnen die Daten nicht wiederhergestellt werden.'
        'elapsed' = 'Zeit: {0}'
        'empty' = 'Nichts zu verschl\u00fcsseln.'
        'enc_none' = 'Schutz : keiner (nur komprimiert + verschleiert)'
        'enc_on' = 'Verschl\u00fcsselung: AES-256-CBC + HMAC-SHA256, Schl\u00fcssel basierend auf PBKDF2-SHA256 ({0} Iterationen).'
        'err' = 'FEHLER: {0}'
        'exists_q' = 'Zieldatei existiert bereits: {0}  \u00dcberschreiben?'
        'file' = 'Datei       : {0}'
        'forbidden' = 'Dies ist ein Systemordner. Aus Sicherheitsgr\u00fcnden kann hier keine Verschl\u00fcsselung durchgef\u00fchrt werden.'
        'format' = 'FEHLER: Nicht unterst\u00fctzte oder besch\u00e4digte Datei.'
        'g_about' = 'Info'
        'g_about_by' = 'Diese Anwendung wurde von Abdullah ERT\u00dcRK programmiert.'
        'g_about_coffee' = 'Einen Kaffee spendieren'
        'g_add_files' = 'Dateien hinzuf\u00fcgen...'
        'g_add_folder' = 'Ordner hinzuf\u00fcgen...'
        'g_browse' = 'Durchsuchen...'
        'g_btn_free' = 'Ohne Installation verwenden'
        'g_btn_install' = 'Installieren'
        'g_btn_uninstall' = 'Deinstallieren'
        'g_btn_update' = 'Aktualisieren / neu installieren'
        'g_c_over' = 'Alle \u00fcberschreiben'
        'g_c_ren' = 'Umbenennen'
        'g_c_skip' = 'Alle \u00fcberspringen'
        'g_cancel' = 'Abbrechen'
        'g_close' = 'Schlie\u00dfen'
        'g_confirm_un' = 'SecureEncrypt und das zugeh\u00f6rige Kontextmen\u00fc von diesem Computer entfernen?'
        'g_conflict' = 'Bereits vorhanden: {0}'
        'g_continue' = 'Fortfahren?'
        'g_dec_bad' = 'Dies ist keine von SecureEncrypt erstellte _decrypt.cmd-Datei.'
        'g_dec_choose' = 'Datei ausw\u00e4hlen...'
        'g_dec_hint' = 'Die entschl\u00fcsselten Dateien werden in den Ordner extrahiert, in dem sich die _decrypt.cmd-Datei befindet.'
        'g_dec_kf' = 'Schl\u00fcsseldatei:'
        'g_dec_none' = 'Noch keine Datei ausgew\u00e4hlt.'
        'g_dec_pick' = '_decrypt.cmd-Datei zum Entschl\u00fcsseln (per Drag & Drop):'
        'g_dec_pw' = 'Passwort'
        'g_decrypt' = 'Entschl\u00fcsseln'
        'g_del' = 'Umgang mit den Originaldateien nach der Verschl\u00fcsselung:'
        'g_del0' = 'Beibehalten'
        'g_del1' = 'L\u00f6schen'
        'g_del2' = '\u00dcberschreiben und l\u00f6schen'
        'g_done_dec' = 'Fertig \u2013 die Dateien wurden extrahiert.'
        'g_encrypt' = 'Verschl\u00fcsseln'
        'g_items' = 'Zu verschl\u00fcsselnde Dateien und Ordner (per Drag & Drop hierher ziehen):'
        'g_kf' = 'Schl\u00fcsseldatei (optional):'
        'g_modern_skipped' = 'Der Eintrag f\u00fcr das neue Windows 11-Kontextmen\u00fc konnte nicht hinzugef\u00fcgt werden; das klassische Men\u00fc ist installiert.'
        'g_openfolder' = 'Im Ordner anzeigen'
        'g_pw' = 'Passwort (optional)'
        'g_pw_hint' = 'Wenn Passwort und Schl\u00fcsseldatei leer sind, werden die Daten nicht verschl\u00fcsselt: Sie werden lediglich komprimiert und mittels einer einfachen XOR-Operation verborgen (keine echte Sicherheit).'
        'g_pw2' = 'Passwort best\u00e4tigen:'
        'g_remove' = 'Entfernen'
        'g_setup_fail' = 'Der Vorgang konnte nicht abgeschlossen werden.'
        'g_st_cap' = 'Status'
        'g_st_no' = 'Nicht installiert'
        'g_st_yes' = 'Auf diesem Computer installiert'
        'g_sub_dec' = 'AES-256-Entschl\u00fcsselung'
        'g_sub_enc' = 'AES-256 f\u00fcr Dateien und Ordner'
        'g_sub_setup' = 'Kontextmen\u00fc hinzuf\u00fcgen oder entfernen'
        'g_title_dec' = 'SecureEncrypt \u2013 Entschl\u00fcsseln'
        'g_title_enc' = 'SecureEncrypt \u2013 Verschl\u00fcsseln'
        'g_title_setup' = 'SecureEncrypt \u2013 Einrichtung'
        'g_toomany' = 'Zu viele Fehlversuche. Schlie\u00dfen Sie dieses Fenster und \u00f6ffnen Sie die Datei erneut, um es noch einmal zu versuchen.'
        'g_working' = 'Wird verarbeitet...'
        'install_menu' = 'Kontextmen\u00fc (Rechtsklick) hinzugef\u00fcgt: \u201eEncrypt\u201c f\u00fcr Dateien/Ordner, \u201eDecrypt\u201c f\u00fcr *_decrypt.cmd-Dateien.'
        'install_ok' = 'Installation erfolgreich abgeschlossen.'
        'installed' = 'SecureEncrypt ist bereits auf dem System installiert.'
        'installing' = 'Installation l\u00e4uft...'
        'items' = 'Zu verarbeitende Elemente ({0}):'
        'kdf' = 'Schl\u00fcsselableitung (PBKDF2)...'
        'kf_missing' = 'Schl\u00fcsseldatei nicht gefunden: {0}'
        'kf_note' = 'HINWEIS: Wenn sich der Inhalt dieser Schl\u00fcsseldatei \u00e4ndert oder die Datei verloren geht, k\u00f6nnen Ihre Daten nicht mehr ge\u00f6ffnet werden. Erstellen Sie eine Sicherungskopie.'
        'kf_pick_fail' = 'Der Dateidialog konnte nicht ge\u00f6ffnet werden (z. B. unter Server Core). Bitte geben Sie stattdessen den Pfad ein.'
        'kf_pick_title' = 'Schl\u00fcsseldatei ausw\u00e4hlen'
        'lang_name' = 'Deutsch'
        'late_added' = '{0} weiteres Element/weitere Elemente hinzugef\u00fcgt \u2013 insgesamt {1}.'
        'late_skipped' = '\u00dcbersprungen (Systemordner): {0}'
        'lbl_hash' = 'Hashing   '
        'lbl_pack' = 'Packen    '
        'lbl_ver' = '\u00dcberpr\u00fcfen'
        'mac_fail' = 'FEHLER: Integrit\u00e4tspr\u00fcfung FEHLGESCHLAGEN. Die Datei ist besch\u00e4digt oder wurde ver\u00e4ndert. Es wurde nichts extrahiert.'
        'menu' = '  [1] Aktualisieren / Neu installieren |  [2] Deinstallieren |  [3] Beenden'
        'menu_dec' = 'Entschl\u00fcsseln (Secure Encrypt AES-256)'
        'menu_encrypt' = 'Verschl\u00fcsseln (Secure Encrypt AES-256)'
        'menu_open' = 'SecureEncrypt-Fenster \u00f6ffnen'
        'mode_label' = 'Modus     : {0}'
        'mode1' = 'komprimiert + verschleiert (NICHT verschl\u00fcsselt)'
        'mode2' = 'AES-256-verschl\u00fcsselt'
        'more_items' = '  ... und {0} weitere'
        'n_both' = 'Passwort + Schl\u00fcsseldatei'
        'n_kf' = 'Schl\u00fcsseldatei'
        'n_pw' = 'Passwort'
        'need_admin' = 'F\u00fcr die Installation sind Administratorrechte erforderlich. Berechtigung wird angefordert...'
        'needs' = 'Erfordert  : {0}'
        'no_chars' = 'n,nein'
        'no_enc' = 'Kein Passwort oder Schl\u00fcsseldatei: Die Daten werden NICHT verschl\u00fcsselt (nur komprimiert und verschleiert).'
        'not_installed' = 'SecureEncrypt ist nicht auf dem System installiert.'
        'notfound' = 'Pfad nicht gefunden: {0}'
        'out_info' = 'Zieldatei: {0}  ({1})'
        'press' = 'Dr\u00fccken Sie eine beliebige Taste zum Beenden...'
        'pw_mismatch' = 'Die Passw\u00f6rter stimmen nicht \u00fcberein. Bitte erneut versuchen.'
        'pw_strength' = 'Passwortst\u00e4rke: {0}'
        'pw_weak' = 'Dieses Passwort ist schwach. Trotzdem verwenden?'
        'q_adv' = 'Erweiterte Optionen (Schl\u00fcsseldatei, Originale l\u00f6schen)'
        'q_install' = 'M\u00f6chten Sie es installieren?'
        'section' = '================== VERSCHL\u00dcSSELUNGSVORGANG =================='
        'sha' = 'Berechneter SHA256-Hash: {0}'
        'sha_fail' = 'SHA256: FEHLGESCHLAGEN (die Daten stimmen nicht mit dem Original \u00fcberein)'
        'sha_ok' = 'SHA256: ERFOLGREICH'
        'skipped' = '\u00dcbersprungen (nicht zug\u00e4nglich / Verkn\u00fcpfung): {0}'
        'src_info' = 'Elemente : {0}    Gesamtgr\u00f6\u00dfe: {1}'
        'src_sha' = 'SHA256   : {0}'
        'strength0' = 'sehr schwach'
        'strength1' = 'schwach'
        'strength2' = 'mittelm\u00e4\u00dfig'
        'strength3' = 'gut'
        'strength4' = 'stark'
        'success' = 'ERFOLG \u2013 Alle Vorg\u00e4nge wurden abgeschlossen.'
        't_delete' = 'Was soll nach der Verschl\u00fcsselung mit den Originalelementen geschehen?| [N] Beibehalten (Standard)| [D] L\u00f6schen| [S] \u00dcberschreiben und anschlie\u00dfend l\u00f6schen'
        't_delete_ask' = 'Ihre Wahl [N/D/S] (ENTER = N)'
        't_kf' = 'Schl\u00fcsseldatei (Pfad eingeben, Datei hierher ziehen oder \u201e?\u201c f\u00fcr die Dateiauswahl; ENTER zum \u00dcberspringen)'
        't_pw' = 'Passwort (ENTER dr\u00fccken zum \u00dcberspringen)'
        't_pw2' = 'Passwort best\u00e4tigen'
        'uninstall_ok' = 'Deinstallation erfolgreich abgeschlossen.'
        'uninstalling' = 'Deinstallation l\u00e4uft...'
        'unit_h' = 'Std.'
        'unit_m' = 'Min.'
        'unit_s' = 'Sek.'
        'use_hint1' = 'Kann ohne Installation verwendet werden.'
        'use_hint2' = 'Um Dateien oder Ordner zu verschl\u00fcsseln, ziehen Sie diese per Drag-and-Drop auf dieses Skript (auch mehrere gleichzeitig sind m\u00f6glich).'
        'verified' = '\u00dcberpr\u00fcfung erfolgreich (Ausgabedatei entschl\u00fcsselt und abgeglichen).'
        'warning' = '========================== WARNUNG =========================='
        'wrong' = 'Falsches Passwort oder falsche Schl\u00fcsseldatei ({0}/{1}).'
        'yes_chars' = 'j,ja'
        'yn' = 'J/N'
        'yn_invalid' = 'Bitte antworten Sie mit {0} oder {1} (oder dr\u00fccken Sie die EINGABETASTE f\u00fcr die Standardeinstellung).'
    }
    'en' = @{
        'admin_denied' = 'Administrator permission was not granted.'
        'big_warn' = 'NOTE: The file is larger than 4 GB; Windows cannot open it by double-clicking. To decrypt it, right-click the file and select "Decrypt," or drag and drop it onto the SecureEncrypt.cmd file to begin the decryption process.'
        'cancelled' = 'Cancelled.'
        'changed' = 'A source file changed while it was being processed. Please try again.'
        'choice' = 'Your choice [1/2/3] (type the number, then press ENTER)'
        'comp_off' = 'not compressed (already compressed type or very large data)'
        'comp_on' = 'GZip compressed'
        'compile' = 'The helper code could not be compiled (.NET Framework is required). Details:'
        'del_fail' = 'Could not delete all originals: {0}'
        'del_ok' = 'Original item(s) deleted.'
        'del_partial' = 'Some originals could NOT be deleted ({0}); the rest were deleted:'
        'del_partial_hint' = 'The encrypted copy is complete. Close whatever is using these files and delete them manually.'
        'del_skip' = 'Originals were NOT deleted (the output is inside a source folder, or some items were skipped).'
        'done' = 'Done. {0} item(s) extracted to: {1}'
        'dont_forget' = 'IMPORTANT: DO NOT FORGET PASSWORD / KEY FILE. Without it the data cannot be recovered.'
        'elapsed' = 'Time: {0}'
        'empty' = 'Nothing to encrypt.'
        'enc_none' = 'Protection : none (compressed + obfuscated only)'
        'enc_on' = 'Encryption: AES-256-CBC + HMAC-SHA256, key from PBKDF2-SHA256 ({0} iterations).'
        'err' = 'ERROR: {0}'
        'exists_q' = 'Output file already exists: {0}  Overwrite?'
        'file' = 'File       : {0}'
        'forbidden' = 'This location is a system folder. Encryption cannot be performed here for security reasons.'
        'format' = 'ERROR: Unsupported or damaged file.'
        'g_about' = 'About'
        'g_about_by' = 'This application was coded by Abdullah ERT\u00dcRK.'
        'g_about_coffee' = 'Buy me a coffee'
        'g_add_files' = 'Add files...'
        'g_add_folder' = 'Add folder...'
        'g_browse' = 'Browse...'
        'g_btn_free' = 'Use without installing'
        'g_btn_install' = 'Install'
        'g_btn_uninstall' = 'Uninstall'
        'g_btn_update' = 'Update / reinstall'
        'g_c_over' = 'Overwrite all'
        'g_c_ren' = 'Rename'
        'g_c_skip' = 'Skip all'
        'g_cancel' = 'Cancel'
        'g_close' = 'Close'
        'g_confirm_un' = 'Remove SecureEncrypt and its right-click menu from this computer?'
        'g_conflict' = 'Already exists: {0}'
        'g_continue' = 'Continue?'
        'g_dec_bad' = 'This is not a _decrypt.cmd file created by SecureEncrypt.'
        'g_dec_choose' = 'Choose file...'
        'g_dec_hint' = 'The decrypted files are extracted to the location where the _decrypt.cmd file is found.'
        'g_dec_kf' = 'Key file:'
        'g_dec_none' = 'No file chosen yet.'
        'g_dec_pick' = '_decrypt.cmd file to decrypt (drag and drop):'
        'g_dec_pw' = 'Password'
        'g_decrypt' = 'Decrypt'
        'g_del' = 'What to do with the originals after encryption:'
        'g_del0' = 'Keep them'
        'g_del1' = 'Delete them'
        'g_del2' = 'Overwrite and delete them'
        'g_done_dec' = 'Done - the files were extracted.'
        'g_encrypt' = 'Encrypt'
        'g_items' = 'Files and folders to encrypt (drag and drop them here):'
        'g_kf' = 'Key file (optional):'
        'g_modern_skipped' = 'The entry for the new Windows 11 context menu could not be added; the classic menu is installed.'
        'g_openfolder' = 'Show in folder'
        'g_pw' = 'Password (optional)'
        'g_pw_hint' = 'If the password and the key file are empty, the data is not encrypted: it is only compressed and hidden with a simple XOR (no real security).'
        'g_pw2' = 'Confirm password:'
        'g_remove' = 'Remove'
        'g_setup_fail' = 'The operation could not be completed.'
        'g_st_cap' = 'Status'
        'g_st_no' = 'Not installed'
        'g_st_yes' = 'Installed on this computer'
        'g_sub_dec' = 'AES-256 decryption'
        'g_sub_enc' = 'AES-256 encryption for files and folders'
        'g_sub_setup' = 'Add or remove the right-click menu'
        'g_title_dec' = 'SecureEncrypt - Decrypt'
        'g_title_enc' = 'SecureEncrypt - Encrypt'
        'g_title_setup' = 'SecureEncrypt - Setup'
        'g_toomany' = 'Too many wrong attempts. Close this window and open the file again to retry.'
        'g_working' = 'Working...'
        'install_menu' = 'Right-click menu added: Encrypt for files/folders, Decrypt for *_decrypt.cmd files.'
        'install_ok' = 'Installation completed successfully.'
        'installed' = 'SecureEncrypt is already installed on the system.'
        'installing' = 'Installing...'
        'items' = 'Items to process ({0}):'
        'kdf' = 'Deriving key (PBKDF2)...'
        'kf_missing' = 'Key file not found: {0}'
        'kf_note' = 'NOTE: if the content of this key file changes or the file is lost, your data can no longer be opened. Keep a backup copy.'
        'kf_pick_fail' = 'The file dialog could not be opened (for example on Server Core). Please type the path instead.'
        'kf_pick_title' = 'Select the key file'
        'lang_name' = 'English'
        'late_added' = 'Added {0} more selected item(s) - {1} in total.'
        'late_skipped' = 'Skipped (system folder): {0}'
        'lbl_hash' = 'Hashing   '
        'lbl_pack' = 'Packing   '
        'lbl_ver' = 'Verifying '
        'mac_fail' = 'ERROR: Integrity check FAILED. The file is corrupted or has been modified. Nothing was extracted.'
        'menu' = '  [1] Update / reinstall|  [2] Uninstall|  [3] Exit'
        'menu_dec' = 'Decrypt (Secure Encrypt AES-256)'
        'menu_encrypt' = 'Encrypt (Secure Encrypt AES-256)'
        'menu_open' = 'Open the SecureEncrypt window'
        'mode_label' = 'Mode     : {0}'
        'mode1' = 'compressed + obfuscated (NOT encrypted)'
        'mode2' = 'AES-256 encrypted'
        'more_items' = '  ... and {0} more'
        'n_both' = 'password + key file'
        'n_kf' = 'key file'
        'n_pw' = 'password'
        'need_admin' = 'Administrator privileges required for installation. Requesting permission...'
        'needs' = 'Requires   : {0}'
        'no_chars' = 'n,no'
        'no_enc' = 'No password or key file: data will NOT be encrypted (only compressed and obfuscated).'
        'not_installed' = 'SecureEncrypt is not installed on the system.'
        'notfound' = 'Path not found: {0}'
        'out_info' = 'Decrypt file: {0}  ({1})'
        'press' = 'Press any key to exit...'
        'pw_mismatch' = 'Passwords do not match. Try again.'
        'pw_strength' = 'Password strength: {0}'
        'pw_weak' = 'This password is weak. Use it anyway?'
        'q_adv' = 'Advanced options (key file, delete originals)'
        'q_install' = 'Do you want to install it'
        'section' = '================== ENCRYPT PROCESS =================='
        'sha' = 'Calculated SHA256: {0}'
        'sha_fail' = 'SHA256: FAILED (the data does not match the original)'
        'sha_ok' = 'SHA256: SUCCESS'
        'skipped' = 'Skipped (not accessible / link): {0}'
        'src_info' = 'Entries  : {0}    Total size: {1}'
        'src_sha' = 'SHA256   : {0}'
        'strength0' = 'very weak'
        'strength1' = 'weak'
        'strength2' = 'fair'
        'strength3' = 'good'
        'strength4' = 'strong'
        'success' = 'SUCCESS - All operations completed.'
        't_delete' = 'What should happen to the original item(s) after encryption?|  [N] Keep them (default)|  [D] Delete them|  [S] Overwrite, then delete them'
        't_delete_ask' = 'Your choice [N/D/S] (ENTER = N)'
        't_kf' = 'Key file (path, drag a file here, or ? to browse; ENTER to skip)'
        't_pw' = 'Password (press ENTER to skip)'
        't_pw2' = 'Confirm password'
        'uninstall_ok' = 'Uninstallation completed successfully.'
        'uninstalling' = 'Uninstalling...'
        'unit_h' = 'h'
        'unit_m' = 'min'
        'unit_s' = 's'
        'use_hint1' = 'You can use it without installation.'
        'use_hint2' = 'To encrypt files or folders, drag and drop them onto this script (several at once is fine).'
        'verified' = 'Verification passed (output decrypted and compared).'
        'warning' = '========================== WARNING =========================='
        'wrong' = 'Wrong password or key file ({0}/{1}).'
        'yes_chars' = 'y,yes'
        'yn' = 'Y/N'
        'yn_invalid' = 'Please answer {0} or {1} (or press ENTER for the default).'
    }
    'tr' = @{
        'admin_denied' = 'Y\u00f6netici izni verilmedi.'
        'big_warn' = 'D\u0130KKAT: Dosya 4 GB''tan b\u00fcy\u00fck; Windows bunu \u00e7ift t\u0131klayarak a\u00e7amaz. \u00c7\u00f6zmek i\u00e7in dosyaya sa\u011f t\u0131klay\u0131p "\u015eifreyi \u00e7\u00f6z" \u00fc se\u00e7in veya SecureEncrypt.cmd dosyas\u0131na s\u00fcr\u00fckleyerek \u015fifre \u00e7\u00f6zme i\u015flemini ba\u015flat\u0131n.'
        'cancelled' = '\u0130ptal edildi.'
        'changed' = '\u0130\u015flem s\u0131ras\u0131nda bir kaynak dosya de\u011fi\u015fti. L\u00fctfen tekrar deneyin.'
        'choice' = 'Se\u00e7iminiz [1/2/3] (numaray\u0131 yaz\u0131p ENTER''a bas\u0131n)'
        'comp_off' = 's\u0131k\u0131\u015ft\u0131r\u0131lmad\u0131 (zaten s\u0131k\u0131\u015ft\u0131r\u0131lm\u0131\u015f t\u00fcr ya da \u00e7ok b\u00fcy\u00fck veri)'
        'comp_on' = 'GZip ile s\u0131k\u0131\u015ft\u0131r\u0131ld\u0131'
        'compile' = 'Yard\u0131mc\u0131 kod derlenemedi (.NET Framework gerekli). Ayr\u0131nt\u0131lar:'
        'del_fail' = 'Orijinallerin tamam\u0131 silinemedi: {0}'
        'del_ok' = 'Orijinal \u00f6\u011fe(ler) silindi.'
        'del_partial' = 'Baz\u0131 orijinaller S\u0130L\u0130NEMED\u0130 ({0}); geri kalanlar silindi:'
        'del_partial_hint' = '\u015eifreli kopya eksiksiz olu\u015fturuldu. Bu dosyalar\u0131 kullanan program\u0131 kapat\u0131p elle silebilirsiniz.'
        'del_skip' = 'Orijinaller S\u0130L\u0130NMED\u0130 (\u00e7\u0131kt\u0131 bir kaynak klas\u00f6r\u00fcn i\u00e7inde ya da baz\u0131 \u00f6\u011feler atland\u0131).'
        'done' = 'Tamamland\u0131. {0} \u00f6\u011fe \u015furaya \u00e7\u0131kar\u0131ld\u0131: {1}'
        'dont_forget' = '\u00d6NEML\u0130: PAROLAYI / ANAHTAR DOSYASINI UNUTMAYIN. Onsuz verinin geri getirilmesi m\u00fcmk\u00fcn de\u011fildir.'
        'elapsed' = 'S\u00fcre: {0}'
        'empty' = '\u015eifrelenecek bir \u015fey yok.'
        'enc_none' = 'Koruma     : yok (yaln\u0131zca s\u0131k\u0131\u015ft\u0131r\u0131lm\u0131\u015f + gizlenmi\u015f)'
        'enc_on' = '\u015eifreleme: AES-256-CBC + HMAC-SHA256, anahtar PBKDF2-SHA256 ({0} yineleme) ile t\u00fcretilir.'
        'err' = 'HATA: {0}'
        'exists_q' = '\u00c7\u0131kt\u0131 dosyas\u0131 zaten var: {0}  \u00dczerine yaz\u0131ls\u0131n m\u0131?'
        'file' = 'Dosya      : {0}'
        'forbidden' = 'Bu konum bir sistem klas\u00f6r\u00fcd\u00fcr. G\u00fcvenlik nedeniyle burada \u015fifreleme yap\u0131lamaz.'
        'format' = 'HATA: Desteklenmeyen veya bozuk dosya.'
        'g_about' = 'Hakk\u0131nda'
        'g_about_by' = 'Bu uygulama Abdullah ERT\u00dcRK taraf\u0131ndan kodlanm\u0131\u015ft\u0131r.'
        'g_about_coffee' = 'Bana bir kahve \u0131smarla'
        'g_add_files' = 'Dosya ekle...'
        'g_add_folder' = 'Klas\u00f6r ekle...'
        'g_browse' = 'G\u00f6zat...'
        'g_btn_free' = 'Kurulum yapmadan kullan'
        'g_btn_install' = 'Kur'
        'g_btn_uninstall' = 'Kald\u0131r'
        'g_btn_update' = 'G\u00fcncelle / yeniden kur'
        'g_c_over' = 'Hepsinin \u00fczerine yaz'
        'g_c_ren' = 'Yeniden adland\u0131r'
        'g_c_skip' = 'Hepsini atla'
        'g_cancel' = '\u0130ptal'
        'g_close' = 'Kapat'
        'g_confirm_un' = 'SecureEncrypt ve sa\u011f t\u0131k men\u00fcs\u00fc bu bilgisayardan kald\u0131r\u0131ls\u0131n m\u0131?'
        'g_conflict' = 'Zaten var: {0}'
        'g_continue' = 'Devam edilsin mi?'
        'g_dec_bad' = 'Bu dosya SecureEncrypt ile olu\u015fturulmu\u015f bir _decrypt.cmd dosyas\u0131 de\u011fil.'
        'g_dec_choose' = 'Dosya se\u00e7...'
        'g_dec_hint' = '\u00c7\u00f6z\u00fclen dosyalar, _decrypt.cmd dosyas\u0131n\u0131n bulundu\u011fu konuma \u00e7\u0131kar\u0131l\u0131r.'
        'g_dec_kf' = 'Anahtar dosyas\u0131:'
        'g_dec_none' = 'Hen\u00fcz dosya se\u00e7ilmedi.'
        'g_dec_pick' = '\u00c7\u00f6z\u00fclecek _decrypt.cmd dosyas\u0131 (s\u00fcr\u00fckleyip b\u0131rak\u0131n):'
        'g_dec_pw' = 'Parola'
        'g_decrypt' = '\u015eifreyi \u00c7\u00f6z'
        'g_del' = '\u015eifrelemeden sonra orijinal \u00f6\u011felere ne yap\u0131ls\u0131n:'
        'g_del0' = 'Kals\u0131n'
        'g_del1' = 'Silinsin'
        'g_del2' = '\u00dczerine yaz\u0131l\u0131p silinsin'
        'g_done_dec' = 'Tamamland\u0131 - dosyalar \u00e7\u0131kar\u0131ld\u0131.'
        'g_encrypt' = '\u015eifrele'
        'g_items' = '\u015eifrelenecek dosya ve klas\u00f6rler (buraya s\u00fcr\u00fckleyip b\u0131rakabilirsiniz):'
        'g_kf' = 'Anahtar dosyas\u0131 (iste\u011fe ba\u011fl\u0131):'
        'g_modern_skipped' = 'Windows 11 yeni sa\u011f t\u0131k men\u00fcs\u00fc girdisi eklenemedi; klasik men\u00fc kuruldu.'
        'g_openfolder' = 'Klas\u00f6rde g\u00f6ster'
        'g_pw' = 'Parola (iste\u011fe ba\u011fl\u0131)'
        'g_pw_hint' = 'Parola ve anahtar dosyas\u0131 bo\u015fsa veri \u015fifrelenmez: yaln\u0131zca s\u0131k\u0131\u015ft\u0131r\u0131l\u0131r ve basit bir XOR ile gizlenir (ger\u00e7ek g\u00fcvenlik sa\u011flamaz).'
        'g_pw2' = 'Parolay\u0131 do\u011frulay\u0131n:'
        'g_remove' = 'Kald\u0131r'
        'g_setup_fail' = '\u0130\u015flem tamamlanamad\u0131.'
        'g_st_cap' = 'Durum'
        'g_st_no' = 'Kurulu de\u011fil'
        'g_st_yes' = 'Bu bilgisayarda kurulu'
        'g_sub_dec' = 'AES-256 \u015fifre \u00e7\u00f6zme'
        'g_sub_enc' = 'Dosya ve klas\u00f6rler i\u00e7in AES-256 \u015fifreleme'
        'g_sub_setup' = 'Sa\u011f t\u0131k men\u00fcs\u00fcn\u00fc ekleyin veya kald\u0131r\u0131n'
        'g_title_dec' = 'SecureEncrypt - \u015eifreyi \u00c7\u00f6z'
        'g_title_enc' = 'SecureEncrypt - \u015eifrele'
        'g_title_setup' = 'SecureEncrypt - Kurulum'
        'g_toomany' = '\u00c7ok fazla hatal\u0131 deneme yap\u0131ld\u0131. Pencereyi kapat\u0131p dosyay\u0131 yeniden a\u00e7arak tekrar deneyin.'
        'g_working' = '\u00c7al\u0131\u015f\u0131yor...'
        'install_menu' = 'Sa\u011f t\u0131k men\u00fcs\u00fc eklendi: dosya/klas\u00f6rler i\u00e7in \u015eifrele, *_decrypt.cmd dosyalar\u0131 i\u00e7in \u015eifreyi \u00c7\u00f6z.'
        'install_ok' = 'Kurulum ba\u015far\u0131yla tamamland\u0131.'
        'installed' = 'SecureEncrypt sistemde zaten kurulu.'
        'installing' = 'Kuruluyor...'
        'items' = '\u0130\u015flenecek \u00f6\u011feler ({0}):'
        'kdf' = 'Anahtar t\u00fcretiliyor (PBKDF2)...'
        'kf_missing' = 'Anahtar dosyas\u0131 bulunamad\u0131: {0}'
        'kf_note' = 'NOT: Bu anahtar dosyas\u0131n\u0131n i\u00e7eri\u011fi de\u011fi\u015firse veya dosya kaybolursa verinize bir daha ula\u015f\u0131lamaz. Yede\u011fini saklay\u0131n.'
        'kf_pick_fail' = 'Dosya se\u00e7me penceresi a\u00e7\u0131lamad\u0131 (\u00f6rne\u011fin Server Core). L\u00fctfen yolu yaz\u0131n.'
        'kf_pick_title' = 'Anahtar dosyas\u0131n\u0131 se\u00e7in'
        'lang_name' = 'T\u00fcrk\u00e7e'
        'late_added' = 'Se\u00e7ilen {0} \u00f6\u011fe daha eklendi - toplam {1}.'
        'late_skipped' = 'Atland\u0131 (sistem klas\u00f6r\u00fc): {0}'
        'lbl_hash' = '\u00d6zet al\u0131n\u0131yor'
        'lbl_pack' = 'Paketleniyor '
        'lbl_ver' = 'Do\u011frulan\u0131yor '
        'mac_fail' = 'HATA: B\u00fct\u00fcnl\u00fck denetimi BA\u015eARISIZ. Dosya bozulmu\u015f veya de\u011fi\u015ftirilmi\u015f. Hi\u00e7bir \u015fey \u00e7\u0131kar\u0131lmad\u0131.'
        'menu' = '  [1] G\u00fcncelle / yeniden kur|  [2] Kald\u0131r|  [3] \u00c7\u0131k\u0131\u015f'
        'menu_dec' = '\u015eifreyi \u00c7\u00f6z (Secure Encrypt AES-256)'
        'menu_encrypt' = '\u015eifrele (Secure Encrypt AES-256)'
        'menu_open' = 'SecureEncrypt aray\u00fcz\u00fcn\u00fc a\u00e7'
        'mode_label' = 'Mod       : {0}'
        'mode1' = 's\u0131k\u0131\u015ft\u0131r\u0131lm\u0131\u015f + gizlenmi\u015f (\u015e\u0130FREL\u0130 DE\u011e\u0130L)'
        'mode2' = 'AES-256 ile \u015fifreli'
        'more_items' = '  ... ve {0} \u00f6\u011fe daha'
        'n_both' = 'parola + anahtar dosyas\u0131'
        'n_kf' = 'anahtar dosyas\u0131'
        'n_pw' = 'parola'
        'need_admin' = 'Kurulum i\u00e7in Y\u00f6netici ayr\u0131cal\u0131klar\u0131 gerekiyor. \u0130zin isteniyor...'
        'needs' = 'Gereken    : {0}'
        'no_chars' = 'h,hay\u0131r,hayir,n'
        'no_enc' = 'Parola veya anahtar dosyas\u0131 yok: veri \u015e\u0130FRELENMEYECEK (yaln\u0131zca s\u0131k\u0131\u015ft\u0131r\u0131l\u0131r ve gizlenir).'
        'not_installed' = 'SecureEncrypt sistemde kurulu de\u011fil.'
        'notfound' = 'Yol bulunamad\u0131: {0}'
        'out_info' = '\u00c7\u00f6z\u00fcc\u00fc dosya: {0}  ({1})'
        'press' = '\u00c7\u0131k\u0131\u015f i\u00e7in herhangi bir tu\u015fa bas\u0131n...'
        'pw_mismatch' = 'Parolalar e\u015fle\u015fmiyor. Tekrar deneyin.'
        'pw_strength' = 'Parola g\u00fcc\u00fc: {0}'
        'pw_weak' = 'Bu parola zay\u0131f. Yine de kullan\u0131ls\u0131n m\u0131?'
        'q_adv' = 'Geli\u015fmi\u015f se\u00e7enekler (anahtar dosyas\u0131, orijinalleri silme)'
        'q_install' = 'Kurmak istiyor musunuz'
        'section' = '================== \u015e\u0130FRELEME \u0130\u015eLEM\u0130 =================='
        'sha' = 'Hesaplanan SHA256: {0}'
        'sha_fail' = 'SHA256: BA\u015eARISIZ (veri orijinaliyle e\u015fle\u015fmiyor)'
        'sha_ok' = 'SHA256: BA\u015eARILI'
        'skipped' = 'Atland\u0131 (eri\u015filemiyor / ba\u011flant\u0131): {0}'
        'src_info' = '\u00d6\u011fe say\u0131s\u0131: {0}    Toplam boyut: {1}'
        'src_sha' = 'SHA256    : {0}'
        'strength0' = '\u00e7ok zay\u0131f'
        'strength1' = 'zay\u0131f'
        'strength2' = 'orta'
        'strength3' = 'iyi'
        'strength4' = 'g\u00fc\u00e7l\u00fc'
        'success' = 'BA\u015eARILI - T\u00fcm i\u015flemler tamamland\u0131.'
        't_delete' = '\u015eifrelemeden sonra orijinal \u00f6\u011felere ne yap\u0131ls\u0131n?|  [N] Kals\u0131n (varsay\u0131lan)|  [D] Silinsin|  [S] \u00dczerine yaz\u0131l\u0131p silinsin'
        't_delete_ask' = 'Se\u00e7iminiz [N/D/S] (ENTER = N)'
        't_kf' = 'Anahtar dosyas\u0131 (yol yaz\u0131n, dosyay\u0131 s\u00fcr\u00fckleyin veya ? yaz\u0131p se\u00e7in; atlamak i\u00e7in ENTER)'
        't_pw' = 'Parola (atlamak i\u00e7in ENTER)'
        't_pw2' = 'Parolay\u0131 do\u011frulay\u0131n'
        'uninstall_ok' = 'Kald\u0131rma i\u015flemi ba\u015far\u0131yla tamamland\u0131.'
        'uninstalling' = 'Kald\u0131r\u0131l\u0131yor...'
        'unit_h' = 'sa'
        'unit_m' = 'dk'
        'unit_s' = 'sn'
        'use_hint1' = 'Kurulum yapmadan da kullanabilirsiniz.'
        'use_hint2' = 'Dosya veya klas\u00f6rleri \u015fifrelemek i\u00e7in bu beti\u011fin \u00fczerine s\u00fcr\u00fckleyip b\u0131rak\u0131n (birden fazla olabilir).'
        'verified' = 'Do\u011frulama ba\u015far\u0131l\u0131 (\u00e7\u0131kt\u0131 \u00e7\u00f6z\u00fcl\u00fcp kar\u015f\u0131la\u015ft\u0131r\u0131ld\u0131).'
        'warning' = '========================== UYARI =========================='
        'wrong' = 'Parola veya anahtar dosyas\u0131 yanl\u0131\u015f ({0}/{1}).'
        'yes_chars' = 'e,evet,y'
        'yn' = 'E/H'
        'yn_invalid' = 'L\u00fctfen {0} veya {1} yaz\u0131n (varsay\u0131lan i\u00e7in ENTER).'
    }
}

$LangDecSrc = @'
$LangData = @{
    'de' = @{
        'cancelled' = 'Abgebrochen.'
        'compile' = 'Der Hilfscode konnte nicht kompiliert werden (.NET Framework erforderlich). Details:'
        'conflict' = 'Bereits vorhanden: {0}| [O] Alle \u00fcberschreiben| [R] Umbenennen (beide behalten)| [S] Alle \u00fcberspringen| [C] Abbrechen|Ihre Wahl [O/R/S/C]:'
        'done' = 'Fertig. {0} Element(e) entpackt nach: {1}'
        'elapsed' = 'Zeit: {0}'
        'enc_aes' = 'Schutz   : AES-256-verschl\u00fcsselt'
        'enc_none' = 'Schutz   : keiner (nur komprimiert + verschleiert)'
        'err' = 'FEHLER: {0}'
        'file' = 'Datei      : {0}'
        'footer' = '================== ENTSCHL\u00dcSSELUNGSVORGANG =================='
        'format' = 'FEHLER: Nicht unterst\u00fctzte oder besch\u00e4digte Datei.'
        'g_about' = 'Info'
        'g_about_by' = 'Diese Anwendung wurde von Abdullah ERT\u00dcRK programmiert.'
        'g_about_coffee' = 'Einen Kaffee spendieren'
        'g_browse' = 'Durchsuchen...'
        'g_c_over' = 'Alle \u00fcberschreiben'
        'g_c_ren' = 'Umbenennen'
        'g_c_skip' = 'Alle \u00fcberspringen'
        'g_cancel' = 'Abbrechen'
        'g_close' = 'Schlie\u00dfen'
        'g_conflict' = 'Bereits vorhanden: {0}'
        'g_decrypt' = 'Entschl\u00fcsseln'
        'g_done_dec' = 'Fertig \u2013 die Dateien wurden entpackt.'
        'g_kf' = 'Schl\u00fcsseldatei:'
        'g_openfolder' = 'Im Ordner anzeigen'
        'g_sub_dec' = 'AES-256-Entschl\u00fcsselung'
        'g_title_dec' = 'SecureEncrypt \u2013 Entschl\u00fcsseln'
        'g_toomany' = 'Zu viele Fehlversuche. Schlie\u00dfen Sie dieses Fenster und \u00f6ffnen Sie die Datei erneut, um es noch einmal zu versuchen.'
        'g_working' = 'Wird verarbeitet...'
        'header' = '================== ENTSCHL\u00dcSSELUNGSVORGANG =================='
        'kdf' = 'Schl\u00fcsselableitung (PBKDF2): Passwort und Schl\u00fcsseldatei werden \u00fcberpr\u00fcft.'
        'kf_missing' = 'Schl\u00fcsseldatei nicht gefunden: {0}'
        'kf_pick_fail' = 'Der Dateidialog konnte nicht ge\u00f6ffnet werden (z. B. unter Server Core). Bitte geben Sie stattdessen den Pfad ein.'
        'kf_pick_title' = 'Schl\u00fcsseldatei ausw\u00e4hlen'
        'lang_name' = 'Deutsch'
        'lbl_ext' = 'Entpacken'
        'lbl_ver' = '\u201e\u00dcberpr\u00fcfung von \u201c'
        'mac_fail' = 'FEHLER: Integrit\u00e4tspr\u00fcfung FEHLGESCHLAGEN. Die Datei ist besch\u00e4digt oder wurde ver\u00e4ndert. Es wurde nichts extrahiert.'
        'n_both' = 'Passwort + Schl\u00fcsseldatei'
        'n_kf' = 'Schl\u00fcsseldatei'
        'n_pw' = 'Passwort'
        'needs' = 'Erfordert  : {0}'
        'press' = 'Dr\u00fccken Sie eine beliebige Taste zum Beenden...'
        'sha' = 'Berechneter SHA256-Hash: {0}'
        'sha_fail' = 'SHA256: FEHLGESCHLAGEN (die Daten stimmen nicht mit dem Original \u00fcberein)'
        'sha_ok' = 'SHA256: ERFOLGREICH'
        't_kf' = 'Schl\u00fcsseldatei (Pfad; Datei hierher ziehen oder \u201e?\u201c f\u00fcr die Dateiauswahl eingeben)'
        't_pw' = 'Passwort'
        'unit_h' = 'Std.'
        'unit_m' = 'Min.'
        'unit_s' = 'Sek.'
        'wrong' = 'Falsches Passwort oder falsche Schl\u00fcsseldatei ({0}/{1}).'
    }
    'en' = @{
        'cancelled' = 'Cancelled.'
        'compile' = 'The helper code could not be compiled (.NET Framework is required). Details:'
        'conflict' = 'Already exists: {0}|  [O] Overwrite all|  [R] Rename (keep both)|  [S] Skip all|  [C] Cancel|Your choice [O/R/S/C]:'
        'done' = 'Done. {0} item(s) extracted to: {1}'
        'elapsed' = 'Time: {0}'
        'enc_aes' = 'Protection : AES-256 encrypted'
        'enc_none' = 'Protection : none (compressed + obfuscated only)'
        'err' = 'ERROR: {0}'
        'file' = 'File       : {0}'
        'footer' = '================== DECRYPT PROCESS =================='
        'format' = 'ERROR: Unsupported or damaged file.'
        'g_about' = 'About'
        'g_about_by' = 'This application was coded by Abdullah ERT\u00dcRK.'
        'g_about_coffee' = 'Buy me a coffee'
        'g_browse' = 'Browse...'
        'g_c_over' = 'Overwrite all'
        'g_c_ren' = 'Rename'
        'g_c_skip' = 'Skip all'
        'g_cancel' = 'Cancel'
        'g_close' = 'Close'
        'g_conflict' = 'Already exists: {0}'
        'g_decrypt' = 'Decrypt'
        'g_done_dec' = 'Done - the files were extracted.'
        'g_kf' = 'Key file:'
        'g_openfolder' = 'Show in folder'
        'g_sub_dec' = 'AES-256 decryption'
        'g_title_dec' = 'SecureEncrypt - Decrypt'
        'g_toomany' = 'Too many wrong attempts. Close this window and open the file again to retry.'
        'g_working' = 'Working...'
        'header' = '================== DECRYPT PROCESS =================='
        'kdf' = 'Deriving key (PBKDF2): verifying password and key file.'
        'kf_missing' = 'Key file not found: {0}'
        'kf_pick_fail' = 'The file dialog could not be opened (for example on Server Core). Please type the path instead.'
        'kf_pick_title' = 'Select the key file'
        'lang_name' = 'English'
        'lbl_ext' = 'Extracting'
        'lbl_ver' = 'Verifying '
        'mac_fail' = 'ERROR: Integrity check FAILED. The file is corrupted or has been modified. Nothing was extracted.'
        'n_both' = 'password + key file'
        'n_kf' = 'key file'
        'n_pw' = 'password'
        'needs' = 'Requires   : {0}'
        'press' = 'Press any key to exit...'
        'sha' = 'Calculated SHA256: {0}'
        'sha_fail' = 'SHA256: FAILED (the data does not match the original)'
        'sha_ok' = 'SHA256: SUCCESS'
        't_kf' = 'Key file (path, drag the file here, or ? to browse)'
        't_pw' = 'Password'
        'unit_h' = 'h'
        'unit_m' = 'min'
        'unit_s' = 's'
        'wrong' = 'Wrong password or key file ({0}/{1}).'
    }
    'tr' = @{
        'cancelled' = '\u0130ptal edildi.'
        'compile' = 'Yard\u0131mc\u0131 kod derlenemedi (.NET Framework gerekli). Ayr\u0131nt\u0131lar:'
        'conflict' = 'Zaten var: {0}|  [O] Hepsinin \u00fczerine yaz|  [R] Yeniden adland\u0131r (ikisini de tut)|  [S] Hepsini atla|  [C] \u0130ptal|Se\u00e7iminiz [O/R/S/C]:'
        'done' = 'Tamamland\u0131. {0} \u00f6\u011fe \u015furaya \u00e7\u0131kar\u0131ld\u0131: {1}'
        'elapsed' = 'S\u00fcre: {0}'
        'enc_aes' = 'Koruma     : AES-256 ile \u015fifreli'
        'enc_none' = 'Koruma     : yok (yaln\u0131zca s\u0131k\u0131\u015ft\u0131r\u0131lm\u0131\u015f + gizlenmi\u015f)'
        'err' = 'HATA: {0}'
        'file' = 'Dosya      : {0}'
        'footer' = '================== \u015e\u0130FRE \u00c7\u00d6ZME \u0130\u015eLEM\u0130 =================='
        'format' = 'HATA: Desteklenmeyen veya bozuk dosya.'
        'g_about' = 'Hakk\u0131nda'
        'g_about_by' = 'Bu uygulama Abdullah ERT\u00dcRK taraf\u0131ndan kodlanm\u0131\u015ft\u0131r.'
        'g_about_coffee' = 'Bana bir kahve \u0131smarla'
        'g_browse' = 'G\u00f6zat...'
        'g_c_over' = 'Hepsinin \u00fczerine yaz'
        'g_c_ren' = 'Yeniden adland\u0131r'
        'g_c_skip' = 'Hepsini atla'
        'g_cancel' = '\u0130ptal'
        'g_close' = 'Kapat'
        'g_conflict' = 'Zaten var: {0}'
        'g_decrypt' = '\u015eifreyi \u00c7\u00f6z'
        'g_done_dec' = 'Tamamland\u0131 - dosyalar \u00e7\u0131kar\u0131ld\u0131.'
        'g_kf' = 'Anahtar dosyas\u0131:'
        'g_openfolder' = 'Klas\u00f6rde g\u00f6ster'
        'g_sub_dec' = 'AES-256 \u015fifre \u00e7\u00f6zme'
        'g_title_dec' = 'SecureEncrypt - \u015eifreyi \u00c7\u00f6z'
        'g_toomany' = '\u00c7ok fazla hatal\u0131 deneme yap\u0131ld\u0131. Pencereyi kapat\u0131p dosyay\u0131 yeniden a\u00e7arak tekrar deneyin.'
        'g_working' = '\u00c7al\u0131\u015f\u0131yor...'
        'header' = '================== \u015e\u0130FRE \u00c7\u00d6ZME \u0130\u015eLEM\u0130 =================='
        'kdf' = 'Anahtar t\u00fcretiliyor (PBKDF2): Parola ve anahtar dosyas\u0131 do\u011frulan\u0131yor.'
        'kf_missing' = 'Anahtar dosyas\u0131 bulunamad\u0131: {0}'
        'kf_pick_fail' = 'Dosya se\u00e7me penceresi a\u00e7\u0131lamad\u0131 (\u00f6rne\u011fin Server Core). L\u00fctfen yolu yaz\u0131n.'
        'kf_pick_title' = 'Anahtar dosyas\u0131n\u0131 se\u00e7in'
        'lang_name' = 'T\u00fcrk\u00e7e'
        'lbl_ext' = '\u00c7\u0131kar\u0131l\u0131yor '
        'lbl_ver' = 'Do\u011frulan\u0131yor'
        'mac_fail' = 'HATA: B\u00fct\u00fcnl\u00fck denetimi BA\u015eARISIZ. Dosya bozulmu\u015f veya de\u011fi\u015ftirilmi\u015f. Hi\u00e7bir \u015fey \u00e7\u0131kar\u0131lmad\u0131.'
        'n_both' = 'parola + anahtar dosyas\u0131'
        'n_kf' = 'anahtar dosyas\u0131'
        'n_pw' = 'parola'
        'needs' = 'Gereken    : {0}'
        'press' = '\u00c7\u0131k\u0131\u015f i\u00e7in herhangi bir tu\u015fa bas\u0131n...'
        'sha' = 'Hesaplanan SHA256: {0}'
        'sha_fail' = 'SHA256: BA\u015eARISIZ (veri orijinaliyle e\u015fle\u015fmiyor)'
        'sha_ok' = 'SHA256: BA\u015eARILI'
        't_kf' = 'Anahtar dosyas\u0131 (yol yaz\u0131n, dosyay\u0131 s\u00fcr\u00fckleyin veya ? yaz\u0131p se\u00e7in)'
        't_pw' = 'Parola'
        'unit_h' = 'sa'
        'unit_m' = 'dk'
        'unit_s' = 'sn'
        'wrong' = 'Parola veya anahtar dosyas\u0131 yanl\u0131\u015f ({0}/{1}).'
    }
}
'@

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
public delegate void ProgressHandler(string label, int percent);
public delegate void StatusHandler(string text);
public delegate int ConflictHandler(string target);

public class ProgressBar
{
public static string Label = "";
public static ProgressHandler Sink;
public static volatile bool CancelRequested;
private long total;
private long done;
private int last = -1;

public ProgressBar(long total) { this.total = total; Draw(); }

public void Add(long n)
{
if (CancelRequested) throw new OperationCanceledException();
done += n; Draw();
}

private void Draw()
{
int pct = total <= 0 ? 100 : (int)(done * 100 / total);
if (pct > 100) pct = 100;
if (pct == last) return;
last = pct;
if (Sink != null) { Sink(Label, pct); return; }
int bar = pct * 30 / 100;
Console.Write("\r" + Label + " [" + new string('=', bar) + new string(' ', 30 - bar) + "] " + pct + "%  ");
}

public void Finish() { done = total; Draw(); if (Sink == null) Console.WriteLine(); }
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
public static StatusHandler StatusSink;
public static ConflictHandler ConflictSink;
public static string LastSha = "";
public static long LastCount;
public static long LastTotal;
public const long GzipLimit = 3758096384L;     // 3.5 GiB
public static long TotalSize(string[] items, long stopAt)
{
long sum = 0;
for (int i = 0; i < items.Length; i++)
{
try
{
if (File.Exists(items[i])) sum += new FileInfo(items[i]).Length;
else if (Directory.Exists(items[i])) sum += DirSize(items[i], stopAt - sum);
}
catch { }
if (sum >= stopAt) return sum;
}
return sum;
}

private static long DirSize(string dir, long stopAt)
{
long sum = 0;
try
{
string[] files = Directory.GetFiles(dir);
for (int i = 0; i < files.Length; i++)
{
try { sum += new FileInfo(files[i]).Length; } catch { }
if (sum >= stopAt) return sum;
}
string[] subs = Directory.GetDirectories(dir);
for (int i = 0; i < subs.Length; i++)
{
sum += DirSize(subs[i], stopAt - sum);
if (sum >= stopAt) return sum;
}
}
catch { }
return sum;
}
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
if (StatusSink != null) StatusSink(LblKdf); else Console.WriteLine(LblKdf);
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
if (ConflictMode == 0 && ConflictSink != null)
{
ConflictMode = ConflictSink(target);
if (ConflictMode < 1 || ConflictMode > 3) throw new OperationCanceledException();
}
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

$GuiSrc = @'
namespace SE.UI
{
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;
using System.Runtime.InteropServices;
using System.Security;
using System.Text;
using System.Threading;
using System.Windows.Forms;
public static class Ui
{
public static Dictionary<string, string> S = new Dictionary<string, string>();
public static string[] CompressedExt = new string[0];
public static volatile bool LastOk;
internal static Exception Failure;
public static void Put(string k, string v) { S[k] = v; }
public static string LangRequest = "";
public static string[] KeptItems = new string[0];
internal static int KeptTab;
internal static string KeptDecFile = "";
internal static string[] LangCodes = new string[0];
internal static string[] LangNames = new string[0];
internal static string LangCurrent = "";

public static void SetLanguages(string[] codes, string[] names, string current)
{
LangCodes = codes; LangNames = names; LangCurrent = current;
}

public static string T(string k)
{
string v;
if (S.TryGetValue(k, out v)) return v;
return k;
}

public static string TF(string k, object a0, object a1)
{
return string.Format(T(k), a0, a1);
}

internal static string FmtSize(double n)
{
if (n >= 1073741824.0) return string.Format("{0:N2} GB", n / 1073741824.0);
if (n >= 1048576.0) return string.Format("{0:N2} MB", n / 1048576.0);
return string.Format("{0:N2} KB", n / 1024.0);
}

public static string FmtDuration(double sec)
{
string h = T("unit_h"), m = T("unit_m"), s = T("unit_s");
if (sec < 60.0) return string.Format("{0:F2} {1}", sec, s);
long total = (long)Math.Round(sec);
long hh = total / 3600, mm = (total % 3600) / 60, ss = total % 60;
if (hh > 0) return string.Format("{0} {1} {2} {3} {4} {5}", hh, h, mm, m, ss, s);
return string.Format("{0} {1} {2} {3}", mm, m, ss, s);
}

internal static bool Forbidden(string full)
{
string up = Environment.GetEnvironmentVariable("USERPROFILE");
if (!string.IsNullOrEmpty(up))
{
up = up.TrimEnd('\\') + "\\";
if (full.StartsWith(up, StringComparison.OrdinalIgnoreCase)) return false;
}
string root = Path.GetPathRoot(full).TrimEnd('\\');
string sysDrive = Environment.GetEnvironmentVariable("SystemDrive");
if (sysDrive != null && string.Equals(root, sysDrive, StringComparison.OrdinalIgnoreCase)) return true;
if (full.IndexOf("$Recycle.Bin", StringComparison.OrdinalIgnoreCase) >= 0) return true;
if (full.IndexOf("System Volume Information", StringComparison.OrdinalIgnoreCase) >= 0) return true;
return false;
}

internal static SecureString ToSecure(string s)
{
SecureString r = new SecureString();
for (int i = 0; i < s.Length; i++) r.AppendChar(s[i]);
return r;
}

internal static string ErrorText(Exception ex)
{
if (ex is System.Reflection.TargetInvocationException && ex.InnerException != null) ex = ex.InnerException;
if (ex is OperationCanceledException) return T("cancelled");
if (ex is System.Security.Cryptography.CryptographicException) return T("mac_fail");
if (ex.Message == "CHANGED") return T("changed");
if (ex.Message == "EMPTY") return T("empty");
if (ex.Message == "FORMAT") return T("format");
return TF("err", ex.Message, null);
}

internal static string PickFile(IWin32Window owner, string title)
{
OpenFileDialog d = new OpenFileDialog();
d.Title = title;
d.CheckFileExists = true;
d.Multiselect = false;
if (d.ShowDialog(owner) == DialogResult.OK) return d.FileName;
return null;
}

[DllImport("kernel32.dll")] private static extern IntPtr GetConsoleWindow();
[DllImport("kernel32.dll")] private static extern uint GetConsoleProcessList(uint[] list, uint count);
[DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr h, int cmd);
[DllImport("user32.dll")] private static extern bool SetProcessDPIAware();
public static void ShowOwnConsole()
{
try { IntPtr h = GetConsoleWindow(); if (h != IntPtr.Zero) ShowWindow(h, 5); } catch { }
}

internal static void HideOwnConsole()
{
try
{
IntPtr h = GetConsoleWindow();
if (h == IntPtr.Zero) return;
uint[] list = new uint[8];
uint n = GetConsoleProcessList(list, 8);
if (n > 0 && n <= 2) ShowWindow(h, 0);
}
catch { }
}
internal delegate Form FormMaker();
internal static int RunSta(FormMaker make)
{
LastOk = false;
Failure = null;
Thread t = new Thread(new ThreadStart(delegate
{
try
{
try { SetProcessDPIAware(); } catch { }
AppIcon.SetAppId();
try { Application.EnableVisualStyles(); } catch { }
try { Application.SetCompatibleTextRenderingDefault(false); } catch { }
Theme.Init();
Application.Run(make());
}
catch (Exception ex) { Failure = ex; }
}));
t.SetApartmentState(ApartmentState.STA);
t.Start();
t.Join();
if (Failure != null) throw Failure;
return LastOk ? 0 : 1;
}
public static int Encrypt(string[] items, string head)
{
if (items != null && items.Length > 0)
{
List<string> bad = new List<string>();
bool anyOk = false;
for (int i = 0; i < items.Length; i++)
{
string p = items[i];
if (string.IsNullOrEmpty(p)) continue;
string full;
try { full = Path.GetFullPath(p.Trim().Trim('"')); } catch { anyOk = true; continue; }
if (full.Length > 3) full = full.TrimEnd('\\');
if (Forbidden(full)) bad.Add(full); else anyOk = true;
}
if (!anyOk && bad.Count > 0)
{
StringBuilder sb = new StringBuilder(T("forbidden"));
sb.Append("\r\n");
for (int i = 0; i < bad.Count && i < 12; i++) sb.Append("\r\n").Append(bad[i]);
if (bad.Count > 12) sb.Append("\r\n...");
MessageBox.Show(sb.ToString(), T("g_title_enc"), MessageBoxButtons.OK, MessageBoxIcon.Warning);
return 1;
}
}
return RunSta(delegate { return new EncryptForm(items, head); });
}

public static int Decrypt(string selfPath, long dataStart)
{
return RunSta(delegate { return new DecryptForm(selfPath, dataStart); });
}

internal static volatile int SetupAction;
public static int Setup(bool installed, string message, bool messageOk)
{
SetupAction = 0;
RunSta(delegate { return new SetupForm(installed, message, messageOk); });
return SetupAction;
}

private static LinkLabel MakeLink(string text, string url, int x, int y, int w)
{
LinkLabel l = new LinkLabel();
l.Text = text;
l.SetBounds(x, y, w, 22);
l.BackColor = Color.Transparent;
l.LinkColor = Theme.AccentHi;
l.ActiveLinkColor = Theme.Accent2;
l.VisitedLinkColor = Theme.AccentHi;
l.LinkBehavior = LinkBehavior.HoverUnderline;
l.Font = Theme.Body;
l.LinkClicked += new LinkLabelLinkClickedEventHandler(delegate { try { Process.Start(url); } catch { } });
return l;
}

internal static void ShowAbout(IWin32Window owner)
{
Form d = new Form();
d.Text = T("g_about");
d.FormBorderStyle = FormBorderStyle.FixedDialog;
d.StartPosition = FormStartPosition.CenterParent;
d.MaximizeBox = false; d.MinimizeBox = false; d.ShowInTaskbar = false;
d.Font = Theme.Body;
d.ForeColor = Theme.Text;
d.BackColor = Theme.Bg;
d.KeyPreview = true;
d.ClientSize = new Size(520, 236);
Backdrop bg = new Backdrop();
bg.SetBounds(0, 0, 520, 236);
d.Controls.Add(bg);
Card c = new Card();
c.SetBounds(16, 16, 488, 152);
bg.Controls.Add(c);

Label l1 = new Label();
l1.Text = T("g_about_by");
l1.SetBounds(18, 16, 452, 22);
l1.BackColor = Color.Transparent; l1.ForeColor = Theme.Text; l1.Font = Theme.Bold;
c.Controls.Add(l1);
LinkLabel coffee = MakeLink(T("g_about_coffee"), "https://buymeacoffee.com/abdullaherturk", 18, 52, 452);
coffee.Font = Theme.Bold;
c.Controls.Add(coffee);
c.Controls.Add(MakeLink("github.com/abdullah-erturk", "https://github.com/abdullah-erturk", 18, 92, 452));
c.Controls.Add(MakeLink("erturk-dev.netlify.app", "https://erturk-dev.netlify.app", 18, 118, 452));

FlatButton ok = new FlatButton(T("g_close"), true);
ok.SetBounds(384, 182, 120, 38);
ok.Click += new EventHandler(delegate { d.Close(); });
bg.Controls.Add(ok);
d.KeyDown += new KeyEventHandler(delegate(object s, KeyEventArgs e) { if (e.KeyCode == Keys.Escape) d.Close(); });
d.Scale(new SizeF(Theme.F, Theme.F));
d.HandleCreated += new EventHandler(delegate { AppIcon.Apply(d); });
d.ShowDialog(owner);
d.Dispose();
}
internal static int AskConflict(IWin32Window owner, string target)
{
Form d = new Form();
d.Text = T("g_title_dec");
d.FormBorderStyle = FormBorderStyle.FixedDialog;
d.StartPosition = FormStartPosition.CenterParent;
d.MaximizeBox = false; d.MinimizeBox = false; d.ShowInTaskbar = false;
d.Font = Theme.Body;
d.BackColor = Theme.Bg;
d.ForeColor = Theme.Text;
d.ClientSize = new Size(520, 150);
Label l = new Label();
l.Text = TF("g_conflict", target, null);
l.SetBounds(16, 14, 488, 62);
d.Controls.Add(l);
string[] names = new string[] { T("g_c_over"), T("g_c_ren"), T("g_c_skip"), T("g_cancel") };
int[] codes = new int[] { 1, 2, 3, 0 };
int result = 0;
for (int i = 0; i < 4; i++)
{
FlatButton b = new FlatButton(names[i], i == 0);
b.SetBounds(16 + i * 124, 96, 118, 36);
int code = codes[i];
b.Click += new EventHandler(delegate { result = code; d.Close(); });
d.Controls.Add(b);
}
d.Scale(new SizeF(Theme.F, Theme.F));
d.HandleCreated += new EventHandler(delegate { AppIcon.Apply(d); });
d.ShowDialog(owner);
d.Dispose();
return result;
}
}

internal static class Theme
{
public static Color Bg = Color.FromArgb(16, 18, 26);
public static Color CardLine = Color.FromArgb(58, 255, 255, 255);
public static Color Field = Color.FromArgb(18, 20, 29);
public static Color FieldLine = Color.FromArgb(64, 70, 92);
public static Color Text = Color.FromArgb(236, 239, 247);
public static Color Dim = Color.FromArgb(146, 154, 174);
public static Color Accent = Color.FromArgb(99, 102, 241);
public static Color AccentHi = Color.FromArgb(129, 140, 248);
public static Color Accent2 = Color.FromArgb(56, 189, 248);
public static Color Danger = Color.FromArgb(248, 113, 113);
public static Color Warn = Color.FromArgb(251, 191, 36);
public static Color Ok = Color.FromArgb(74, 222, 128);
public const float K = 0.9f;
public static float F = K;
public const int MaxDesignHeight = 704;
public const int DesignWidth = 620;
public static float ComputeScale(float dpi, int workW, int workH, int chrome)
{
float s = dpi * K;
float fitH = (workH - chrome) / (float)MaxDesignHeight;
float fitW = (workW - 24) / (float)DesignWidth;
if (fitH < s) s = fitH;
if (fitW < s) s = fitW;
if (s < 0.6f) s = 0.6f;
return s;
}

public static void Init()
{
try
{
float dpi = 1f;
using (Graphics g = Graphics.FromHwnd(IntPtr.Zero)) dpi = g.DpiX / 96f;
Rectangle wa = Screen.PrimaryScreen.WorkingArea;
int chrome = SystemInformation.CaptionHeight + SystemInformation.FrameBorderSize.Height * 2 + 20;
F = ComputeScale(dpi, wa.Width, wa.Height, chrome);
float kf = F / dpi;                      // fonts follow the same shrink
Body = Make("Segoe UI", 9.5f * kf, FontStyle.Regular);
Small = Make("Segoe UI", 9f * kf, FontStyle.Regular);
Sub = Make("Segoe UI", 10.5f * kf, FontStyle.Regular);
Bold = Make("Segoe UI Semibold", 9.5f * kf, FontStyle.Regular);
Title = Make("Segoe UI Semibold", 16f * kf, FontStyle.Regular);
}
catch { F = K; }
}

public static int Px(int v) { return (int)Math.Round(v * F); }

public static Font Body = Make("Segoe UI", 9.5f * K, FontStyle.Regular);
public static Font Small = Make("Segoe UI", 9f * K, FontStyle.Regular);
public static Font Sub = Make("Segoe UI", 10.5f * K, FontStyle.Regular);
public static Font Bold = Make("Segoe UI Semibold", 9.5f * K, FontStyle.Regular);
public static Font Title = Make("Segoe UI Semibold", 16f * K, FontStyle.Regular);

private static Font Make(string name, float size, FontStyle st)
{
try { return new Font(name, size, st); }
catch { return new Font(SystemFonts.DefaultFont.FontFamily, size, st); }
}

public static GraphicsPath Round(Rectangle r, int radius)
{
GraphicsPath p = new GraphicsPath();
int d = radius * 2;
if (d > r.Height) d = r.Height;
if (d > r.Width) d = r.Width;
if (d < 2) { p.AddRectangle(r); return p; }
p.AddArc(r.X, r.Y, d, d, 180, 90);
p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
p.CloseFigure();
return p;
}
}
internal static class FolderPicker
{
[ComImport, Guid("DC1C5A9C-E88A-4dde-A5A1-60F82A20AEF7")]
private class FileOpenDialogClass { }

[ComImport, Guid("43826d1e-e718-42ee-bc55-a1e261c37bfe"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
private interface IShellItem
{
void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppv);
void GetParent(out IShellItem ppsi);
void GetDisplayName(uint sigdnName, out IntPtr ppszName);
void GetAttributes(uint sfgaoMask, out uint psfgaoAttribs);
void Compare(IShellItem psi, uint hint, out int piOrder);
}

[ComImport, Guid("b63ea76d-1f85-456f-a19c-48159efa858b"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
private interface IShellItemArray
{
void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppvOut);
void GetPropertyStore(int flags, ref Guid riid, out IntPtr ppv);
void GetPropertyDescriptionList(IntPtr keyType, ref Guid riid, out IntPtr ppv);
void GetAttributes(int attribFlags, uint sfgaoMask, out uint psfgaoAttribs);
void GetCount(out uint pdwNumItems);
void GetItemAt(uint dwIndex, out IShellItem ppsi);
void EnumItems(out IntPtr ppenumShellItems);
}
[ComImport, Guid("d57c7288-d4ad-4768-be02-9d969532d960"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
private interface IFileOpenDialog
{
[PreserveSig] int Show(IntPtr parent);
void SetFileTypes(uint cFileTypes, IntPtr rgFilterSpec);
void SetFileTypeIndex(uint iFileType);
void GetFileTypeIndex(out uint piFileType);
void Advise(IntPtr pfde, out uint pdwCookie);
void Unadvise(uint dwCookie);
void SetOptions(uint fos);
void GetOptions(out uint pfos);
void SetDefaultFolder(IShellItem psi);
void SetFolder(IShellItem psi);
void GetFolder(out IShellItem ppsi);
void GetCurrentSelection(out IShellItem ppsi);
void SetFileName([MarshalAs(UnmanagedType.LPWStr)] string pszName);
void GetFileName([MarshalAs(UnmanagedType.LPWStr)] out string pszName);
void SetTitle([MarshalAs(UnmanagedType.LPWStr)] string pszTitle);
void SetOkButtonLabel([MarshalAs(UnmanagedType.LPWStr)] string pszText);
void SetFileNameLabel([MarshalAs(UnmanagedType.LPWStr)] string pszLabel);
void GetResult(out IShellItem ppsi);
void AddPlace(IShellItem psi, int fdap);
void SetDefaultExtension([MarshalAs(UnmanagedType.LPWStr)] string pszDefaultExtension);
void Close(int hr);
void SetClientGuid(ref Guid guid);
void ClearClientData();
void SetFilter(IntPtr pFilter);
void GetResults(out IShellItemArray ppenum);
void GetSelectedItems(out IShellItemArray ppsai);
}
public static string[] Pick(IntPtr owner, string title)
{
try
{
IFileOpenDialog d = (IFileOpenDialog)new FileOpenDialogClass();
uint opts;
d.GetOptions(out opts);
d.SetOptions(opts | 0x20 | 0x40 | 0x200 | 0x800);   // pick folders, file system only, several, path must exist
if (!string.IsNullOrEmpty(title)) d.SetTitle(title);
int hr = d.Show(owner);
if (hr == unchecked((int)0x800704C7)) return new string[0];            // cancelled
if (hr != 0) return null;
IShellItemArray arr;
d.GetResults(out arr);
uint n;
arr.GetCount(out n);
List<string> res = new List<string>();
for (uint i = 0; i < n; i++)
{
IShellItem item;
arr.GetItemAt(i, out item);
IntPtr p;
item.GetDisplayName(0x80058000, out p);                           // SIGDN_FILESYSPATH
string s = Marshal.PtrToStringUni(p);
Marshal.FreeCoTaskMem(p);
if (!string.IsNullOrEmpty(s)) res.Add(s);
}
return res.ToArray();
}
catch { return null; }
}
}
internal static class AppIcon
{
[DllImport("user32.dll")] private static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr w, IntPtr l);
[DllImport("shell32.dll")] private static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string appId);

private static IntPtr small = IntPtr.Zero;
private static IntPtr big = IntPtr.Zero;
public static void SetAppId()
{
try { SetCurrentProcessExplicitAppUserModelID("AbdullahErturk.SecureEncrypt"); } catch { }
}

private static Bitmap Draw(int px)
{
Bitmap bmp = new Bitmap(px, px, PixelFormat.Format32bppArgb);
using (Graphics g = Graphics.FromImage(bmp))
{
g.SmoothingMode = SmoothingMode.AntiAlias;
g.Clear(Color.Transparent);
float s = px / 28f;
g.ScaleTransform(s, s);
Rectangle tile = new Rectangle(0, 0, 28, 28);
using (GraphicsPath p = Theme.Round(tile, 8))
using (LinearGradientBrush b = new LinearGradientBrush(tile, Theme.Accent, Theme.Accent2, 45f))
g.FillPath(b, p);
using (Pen pen = new Pen(Color.White, 2f))
{
g.DrawRectangle(pen, 9, 12, 10, 8);
g.DrawArc(pen, 10, 5, 8, 10, 180, 180);
}
}
return bmp;
}

private static IntPtr Make(int px)
{
using (Bitmap bmp = Draw(px)) return bmp.GetHicon();
}

public static void Apply(Form f)
{
try
{
if (small == IntPtr.Zero) small = Make(Math.Max(16, SystemInformation.SmallIconSize.Width));
if (big == IntPtr.Zero) big = Make(Math.Max(32, SystemInformation.IconSize.Width));
f.Icon = Icon.FromHandle(big);                          // what WinForms itself puts on the window from now on
SendMessage(f.Handle, 0x80, IntPtr.Zero, small);     // WM_SETICON, ICON_SMALL (title bar)
SendMessage(f.Handle, 0x80, new IntPtr(1), big);      // ICON_BIG (Alt+Tab, taskbar)
}
catch { }
}
}
internal static class Glass
{
[DllImport("dwmapi.dll")] private static extern int DwmSetWindowAttribute(IntPtr h, int attr, ref int v, int size);

public static void Apply(IntPtr h)
{
try
{
Version v = Environment.OSVersion.Version;
if (v.Major < 10) return;
int one = 1;
DwmSetWindowAttribute(h, 20, ref one, 4);                   // dark title bar
if (v.Build >= 22621)
{
int acrylic = 3;                                         // DWMSBT_TRANSIENTWINDOW
DwmSetWindowAttribute(h, 38, ref acrylic, 4);
}
}
catch { }
}
}
internal static class Frost
{
public static Bitmap Make(Rectangle r)
{
int w = r.Width, h = r.Height;
Bitmap shot = new Bitmap(w, h, PixelFormat.Format32bppRgb);
using (Graphics g = Graphics.FromImage(shot)) g.CopyFromScreen(r.Location, Point.Empty, r.Size);
int sw = Math.Max(8, w / 12), sh = Math.Max(8, h / 12);
Bitmap small = new Bitmap(sw, sh, PixelFormat.Format32bppRgb);
using (Graphics g = Graphics.FromImage(small))
{
g.InterpolationMode = InterpolationMode.HighQualityBicubic;
g.DrawImage(shot, new Rectangle(0, 0, sw, sh), 0, 0, w, h, GraphicsUnit.Pixel);
}
shot.Dispose();
Blur(small, 3, 3);
Bitmap res = new Bitmap(w, h, PixelFormat.Format32bppRgb);
using (Graphics g = Graphics.FromImage(res))
using (ImageAttributes ia = new ImageAttributes())
{
ia.SetWrapMode(WrapMode.TileFlipXY);
g.InterpolationMode = InterpolationMode.HighQualityBicubic;
g.PixelOffsetMode = PixelOffsetMode.HighQuality;
g.DrawImage(small, new Rectangle(0, 0, w, h), 0, 0, sw, sh, GraphicsUnit.Pixel, ia);
using (SolidBrush b = new SolidBrush(Color.FromArgb(165, 14, 16, 30))) g.FillRectangle(b, 0, 0, w, h);
Backdrop.Glows(g, new Rectangle(0, 0, w, h));
}
small.Dispose();
return res;
}

private static void Blur(Bitmap bmp, int radius, int passes)
{
int w = bmp.Width, h = bmp.Height;
BitmapData d = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadWrite, PixelFormat.Format32bppRgb);
try
{
int stride = d.Stride;
byte[] a = new byte[stride * h];
byte[] b = new byte[a.Length];
Marshal.Copy(d.Scan0, a, 0, a.Length);
for (int i = 0; i < passes; i++)
{
Pass(a, b, w, h, stride, radius, true);
Pass(b, a, w, h, stride, radius, false);
}
Marshal.Copy(a, 0, d.Scan0, a.Length);
}
finally { bmp.UnlockBits(d); }
}

private static void Pass(byte[] src, byte[] dst, int w, int h, int stride, int r, bool horiz)
{
int len = horiz ? w : h;
int lines = horiz ? h : w;
int step = horiz ? 4 : stride;
int lineStep = horiz ? stride : 4;
int div = 2 * r + 1;
for (int l = 0; l < lines; l++)
{
for (int c = 0; c < 3; c++)
{
int bi = l * lineStep + c;
int sum = 0;
for (int i = -r; i <= r; i++) sum += src[bi + Math.Min(len - 1, Math.Max(0, i)) * step];
for (int i = 0; i < len; i++)
{
dst[bi + i * step] = (byte)(sum / div);
sum += src[bi + Math.Min(len - 1, i + r + 1) * step] - src[bi + Math.Max(0, i - r) * step];
}
}
}
}
}

internal class Card : Panel
{
public Card()
{
SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
BackColor = Color.Transparent;
ForeColor = Theme.Text;
Font = Theme.Body;
}

protected override void OnPaint(PaintEventArgs e)
{
e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
using (GraphicsPath p = Theme.Round(r, Theme.Px(14)))
{
using (SolidBrush b = new SolidBrush(Color.FromArgb(150, 14, 16, 26))) e.Graphics.FillPath(b, p);
using (LinearGradientBrush b = new LinearGradientBrush(new Rectangle(0, 0, Math.Max(2, Width), Math.Max(2, Height)),
Color.FromArgb(40, 255, 255, 255), Color.FromArgb(6, 255, 255, 255), 90f))
e.Graphics.FillPath(b, p);
using (Pen pen = new Pen(Theme.CardLine)) e.Graphics.DrawPath(pen, p);
}
}
}
internal class Backdrop : Panel
{
public Backdrop()
{
SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
}

public static void Draw(Graphics g, Rectangle r)
{
g.SmoothingMode = SmoothingMode.AntiAlias;
using (LinearGradientBrush b = new LinearGradientBrush(new Rectangle(r.X, r.Y, Math.Max(2, r.Width), Math.Max(2, r.Height)),
Color.FromArgb(26, 28, 58), Color.FromArgb(11, 13, 22), 65f))
g.FillRectangle(b, r);
Glows(g, r);
}

public static void Glows(Graphics g, Rectangle r)
{
g.SmoothingMode = SmoothingMode.AntiAlias;
Glow(g, new Point(r.Right - 30, r.Y + 30), 300, Color.FromArgb(80, 99, 102, 241));
Glow(g, new Point(r.X + 30, r.Bottom - 20), 280, Color.FromArgb(60, 56, 189, 248));
}

private static void Glow(Graphics g, Point c, int radius, Color col)
{
using (GraphicsPath p = new GraphicsPath())
{
p.AddEllipse(c.X - radius, c.Y - radius, radius * 2, radius * 2);
using (PathGradientBrush b = new PathGradientBrush(p))
{
b.CenterColor = col;
b.SurroundColors = new Color[] { Color.FromArgb(0, col) };
g.FillPath(b, p);
}
}
}

protected override void OnPaintBackground(PaintEventArgs e)
{
GlassForm f = FindForm() as GlassForm;
if (f != null && f.FrostImage != null)
e.Graphics.DrawImage(f.FrostImage, ClientRectangle, new Rectangle(Left, Top, Width, Height), GraphicsUnit.Pixel);
else
Draw(e.Graphics, ClientRectangle);
}
}

internal class Caption : Label
{
public Caption(string text, int x, int y, int w)
{
Text = text;
SetBounds(x, y, w, 18);
BackColor = Color.Transparent;
ForeColor = Theme.Dim;
Font = Theme.Small;
}
}

internal class FlatButton : Control
{
private bool hot, down, primary;

public FlatButton(string text, bool primary)
{
this.primary = primary;
Text = text;
SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable | ControlStyles.SupportsTransparentBackColor, true);
BackColor = Color.Transparent;
Font = Theme.Bold;
Cursor = Cursors.Hand;
TabStop = true;
}

public void PerformClick() { if (Enabled && Visible) OnClick(EventArgs.Empty); }

protected override void OnTextChanged(EventArgs e) { Invalidate(); base.OnTextChanged(e); }

protected override void OnMouseEnter(EventArgs e) { hot = true; Invalidate(); base.OnMouseEnter(e); }
protected override void OnMouseLeave(EventArgs e) { hot = false; down = false; Invalidate(); base.OnMouseLeave(e); }
protected override void OnMouseDown(MouseEventArgs e) { down = true; Focus(); Invalidate(); base.OnMouseDown(e); }
protected override void OnMouseUp(MouseEventArgs e)
{
bool fire = down && hot && e.Button == MouseButtons.Left;
down = false; Invalidate();
base.OnMouseUp(e);
if (fire) OnClick(EventArgs.Empty);
}
protected override void OnKeyDown(KeyEventArgs e)
{
if (e.KeyCode == Keys.Space) { OnClick(EventArgs.Empty); e.Handled = true; }
base.OnKeyDown(e);
}
protected override void OnEnabledChanged(EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }
protected override void OnGotFocus(EventArgs e) { Invalidate(); base.OnGotFocus(e); }
protected override void OnLostFocus(EventArgs e) { Invalidate(); base.OnLostFocus(e); }

protected override void OnPaint(PaintEventArgs e)
{
Graphics g = e.Graphics;
g.SmoothingMode = SmoothingMode.AntiAlias;
g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
Color fill, line, fore;
if (!Enabled) { fill = Color.FromArgb(40, 44, 58); line = fill; fore = Color.FromArgb(100, 106, 124); }
else if (primary)
{
fill = down ? Theme.Accent : (hot ? Theme.AccentHi : Theme.Accent);
line = Theme.AccentHi; fore = Color.White;
}
else
{
fill = down ? Color.FromArgb(52, 57, 76) : (hot ? Color.FromArgb(44, 49, 67) : Color.FromArgb(34, 38, 53));
line = Theme.CardLine; fore = Theme.Text;
}
using (GraphicsPath p = Theme.Round(r, Theme.Px(9)))
{
using (SolidBrush b = new SolidBrush(fill)) g.FillPath(b, p);
using (Pen pen = new Pen(Focused ? Theme.Accent2 : line)) g.DrawPath(pen, p);
}
TextRenderer.DrawText(g, Text, Font, new Rectangle(0, 0, Width, Height), fore,
TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis);
}
}
internal class Field : Control
{
public TextBox Box;
private bool focus;

public Field(bool password)
{
SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor, true);
BackColor = Color.Transparent;
Box = new TextBox();
Box.BorderStyle = BorderStyle.None;
Box.BackColor = Theme.Field;
Box.ForeColor = Theme.Text;
Box.Font = Theme.Body;
Box.UseSystemPasswordChar = password;
Box.GotFocus += new EventHandler(delegate { focus = true; Invalidate(); });
Box.LostFocus += new EventHandler(delegate { focus = false; Invalidate(); });
Controls.Add(Box);
}

public override string Text { get { return Box.Text; } set { Box.Text = value; } }

protected override void OnLayout(LayoutEventArgs e)
{
int h = Box.PreferredHeight;
Box.SetBounds(Theme.Px(12), (Height - h) / 2, Math.Max(10, Width - Theme.Px(24)), h);
base.OnLayout(e);
}

protected override void OnEnabledChanged(EventArgs e) { Box.Enabled = Enabled; Invalidate(); base.OnEnabledChanged(e); }

protected override void OnPaint(PaintEventArgs e)
{
e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
using (GraphicsPath p = Theme.Round(r, Theme.Px(8)))
{
using (SolidBrush b = new SolidBrush(Enabled ? Theme.Field : Color.FromArgb(28, 31, 42))) e.Graphics.FillPath(b, p);
using (Pen pen = new Pen(focus ? Theme.AccentHi : Theme.FieldLine, focus ? 1.6f : 1f)) e.Graphics.DrawPath(pen, p);
}
}
}
internal class Segmented : Control
{
private string[] opts;
private int sel;

public Segmented(string[] options)
{
opts = options;
SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor | ControlStyles.Selectable, true);
BackColor = Color.Transparent;
Font = Theme.Body;
Cursor = Cursors.Hand;
TabStop = true;
}

public int SelectedIndex { get { return sel; } set { sel = value; Invalidate(); } }
public event EventHandler Changed;

private void Pick(int i)
{
if (i == sel) return;
sel = i;
Invalidate();
if (Changed != null) Changed(this, EventArgs.Empty);
}

protected override void OnMouseDown(MouseEventArgs e)
{
if (!Enabled) return;
int i = e.X * opts.Length / Math.Max(1, Width);
Focus();
if (i >= 0 && i < opts.Length) Pick(i);
base.OnMouseDown(e);
}

protected override void OnKeyDown(KeyEventArgs e)
{
if (e.KeyCode == Keys.Right && sel < opts.Length - 1) { Pick(sel + 1); e.Handled = true; }
if (e.KeyCode == Keys.Left && sel > 0) { Pick(sel - 1); e.Handled = true; }
base.OnKeyDown(e);
}

protected override bool IsInputKey(Keys k) { return k == Keys.Left || k == Keys.Right || base.IsInputKey(k); }
protected override void OnEnabledChanged(EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }
protected override void OnGotFocus(EventArgs e) { Invalidate(); base.OnGotFocus(e); }
protected override void OnLostFocus(EventArgs e) { Invalidate(); base.OnLostFocus(e); }

protected override void OnPaint(PaintEventArgs e)
{
Graphics g = e.Graphics;
g.SmoothingMode = SmoothingMode.AntiAlias;
Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
using (GraphicsPath p = Theme.Round(r, r.Height / 2))
{
using (SolidBrush b = new SolidBrush(Theme.Field)) g.FillPath(b, p);
using (Pen pen = new Pen(Focused ? Theme.Accent2 : Theme.FieldLine)) g.DrawPath(pen, p);
}
int w = Width / opts.Length;
for (int i = 0; i < opts.Length; i++)
{
Rectangle cell = new Rectangle(i * w + Theme.Px(3), Theme.Px(3), w - Theme.Px(6), Height - Theme.Px(7));
if (i == sel)
{
using (GraphicsPath p = Theme.Round(cell, cell.Height / 2))
using (LinearGradientBrush b = new LinearGradientBrush(cell, Theme.Accent, Theme.AccentHi, 0f))
g.FillPath(b, p);
}
Color fore = !Enabled ? Color.FromArgb(100, 106, 124) : (i == sel ? Color.White : Theme.Dim);
TextRenderer.DrawText(g, opts[i], Font, cell, fore,
TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis);
}
}
}

internal class GlowBar : Control
{
private int val;

public GlowBar()
{
SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor, true);
BackColor = Color.Transparent;
}

public int Value { get { return val; } set { val = Math.Max(0, Math.Min(100, value)); Invalidate(); } }

protected override void OnPaint(PaintEventArgs e)
{
Graphics g = e.Graphics;
g.SmoothingMode = SmoothingMode.AntiAlias;
Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
using (GraphicsPath p = Theme.Round(r, r.Height / 2))
using (SolidBrush b = new SolidBrush(Theme.Field)) g.FillPath(b, p);
int w = (int)((Width - 1) * (long)val / 100);
if (w < r.Height) w = val > 0 ? r.Height : 0;
if (w > 0)
{
Rectangle f = new Rectangle(0, 0, w, r.Height);
using (GraphicsPath p = Theme.Round(f, f.Height / 2))
using (LinearGradientBrush b = new LinearGradientBrush(new Rectangle(0, 0, Math.Max(2, Width), Height), Theme.Accent, Theme.Accent2, 0f))
g.FillPath(b, p);
}
}
}

internal class ItemList : ListBox
{
public ItemList()
{
DrawMode = DrawMode.OwnerDrawFixed;
ItemHeight = Theme.Px(36);
BorderStyle = BorderStyle.None;
BackColor = Theme.Field;
ForeColor = Theme.Text;
Font = Theme.Body;
IntegralHeight = false;
SelectionMode = SelectionMode.MultiExtended;
}

protected override void OnDrawItem(DrawItemEventArgs e)
{
Graphics g = e.Graphics;
g.SmoothingMode = SmoothingMode.AntiAlias;
bool sel = (e.State & DrawItemState.Selected) != 0;
using (SolidBrush b = new SolidBrush(sel ? Color.FromArgb(70, 99, 102, 241) : Theme.Field)) g.FillRectangle(b, e.Bounds);
if (e.Index < 0) return;
string full = (string)Items[e.Index];
string name = Path.GetFileName(full.TrimEnd('\\'));
if (string.IsNullOrEmpty(name)) name = full;
string dir = Path.GetDirectoryName(full.TrimEnd('\\'));
if (dir == null) dir = "";
bool isDir = Directory.Exists(full);
Rectangle ic = new Rectangle(e.Bounds.X + Theme.Px(8), e.Bounds.Y + Theme.Px(9), Theme.Px(18), Theme.Px(18));
using (GraphicsPath p = Theme.Round(ic, Theme.Px(4)))
using (SolidBrush b = new SolidBrush(isDir ? Theme.Warn : Theme.Accent2)) g.FillPath(b, p);
TextRenderer.DrawText(g, name, Theme.Bold, new Rectangle(e.Bounds.X + Theme.Px(34), e.Bounds.Y + Theme.Px(2), e.Bounds.Width - Theme.Px(40), Theme.Px(18)), Theme.Text,
TextFormatFlags.Left | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix);
TextRenderer.DrawText(g, dir, Theme.Small, new Rectangle(e.Bounds.X + Theme.Px(34), e.Bounds.Y + Theme.Px(18), e.Bounds.Width - Theme.Px(40), Theme.Px(16)), Theme.Dim,
TextFormatFlags.Left | TextFormatFlags.SingleLine | TextFormatFlags.PathEllipsis | TextFormatFlags.NoPrefix);
}
}

internal class DarkColors : ProfessionalColorTable
{
private static Color Back = Color.FromArgb(30, 33, 46);
public override Color ToolStripDropDownBackground { get { return Back; } }
public override Color ImageMarginGradientBegin { get { return Back; } }
public override Color ImageMarginGradientMiddle { get { return Back; } }
public override Color ImageMarginGradientEnd { get { return Back; } }
public override Color MenuBorder { get { return Color.FromArgb(70, 76, 98); } }
public override Color MenuItemBorder { get { return Theme.AccentHi; } }
public override Color MenuItemSelected { get { return Color.FromArgb(62, 68, 104); } }
public override Color MenuItemSelectedGradientBegin { get { return Color.FromArgb(62, 68, 104); } }
public override Color MenuItemSelectedGradientEnd { get { return Color.FromArgb(62, 68, 104); } }
public override Color CheckBackground { get { return Theme.Accent; } }
public override Color CheckSelectedBackground { get { return Theme.Accent; } }
public override Color CheckPressedBackground { get { return Theme.Accent; } }
}

internal abstract class GlassForm : Form
{
private Bitmap frost;
private Point lastFrostPos;
private float dpiScale = 1f;
protected string subtitle = "";
protected Panel pageOpts, pageWork;
protected Panel pageAlt;                // optional second options page (the decrypt tab)
protected Control tabBar;               // disabled while the work page is shown
protected GlowBar bar;
protected Label status;
protected TextBox summary;
protected FlatButton btnOpen, btnStop, btnLang;
internal bool busy;
protected string openTarget;
protected const int HeaderH = 70;

protected GlassForm(string title, string subtitle, int clientH) : this(title, subtitle, 620, clientH) { }
protected GlassForm(string title, string subtitle, int clientW, int clientH)
{
Text = title;
this.subtitle = subtitle;
Font = Theme.Body;
ForeColor = Theme.Text;
BackColor = Theme.Bg;
FormBorderStyle = FormBorderStyle.FixedSingle;
MaximizeBox = false;
StartPosition = FormStartPosition.CenterScreen;
AutoScaleMode = AutoScaleMode.None;       // scaled once, by hand, in OnLoad (WinForms' own scaling runs too early here)
ClientSize = new Size(clientW, clientH);
DoubleBuffered = true;
KeyPreview = true;
Opacity = 0;                    // shown after the frosted background is ready (OnShown)

pageOpts = new Backdrop();
pageOpts.SetBounds(0, HeaderH, clientW, clientH - HeaderH);
pageWork = new Backdrop();
pageWork.SetBounds(0, HeaderH, clientW, clientH - HeaderH);
pageWork.Visible = false;
FlatButton about = new FlatButton(Ui.T("g_about"), false);
about.SetBounds(clientW - 20 - 110, 20, 110, 30);
about.TabStop = false;
about.Click += new EventHandler(delegate { Ui.ShowAbout(this); });
Controls.Add(about);
if (Ui.LangCodes.Length > 1)
{
string cur = Ui.LangCurrent;
for (int i = 0; i < Ui.LangCodes.Length; i++) if (Ui.LangCodes[i] == Ui.LangCurrent) cur = Ui.LangNames[i];
btnLang = new FlatButton(cur + " \u25be", false);
btnLang.SetBounds(clientW - 20 - 110 - 8 - 130, 20, 130, 30);
btnLang.TabStop = false;
btnLang.Click += new EventHandler(OnLangClick);
Controls.Add(btnLang);
}
Controls.Add(pageOpts);
Controls.Add(pageWork);

Card c = new Card();
int ph = clientH - HeaderH;
c.SetBounds(20, 0, clientW - 40, ph - 62);
pageWork.Controls.Add(c);
status = new Label();
status.SetBounds(18, 16, clientW - 76, 22);
status.BackColor = Color.Transparent; status.ForeColor = Theme.Text; status.Font = Theme.Bold;
bar = new GlowBar();
bar.SetBounds(18, 46, clientW - 76, 10);
summary = new TextBox();
summary.Multiline = true; summary.ReadOnly = true; summary.ScrollBars = ScrollBars.Vertical;
summary.BorderStyle = BorderStyle.None;
summary.BackColor = Theme.Field; summary.ForeColor = Theme.Text; summary.Font = Theme.Small;
summary.SetBounds(18, 72, clientW - 76, ph - 62 - 90);
summary.Visible = false;
c.Controls.Add(status); c.Controls.Add(bar); c.Controls.Add(summary);
btnOpen = new FlatButton(Ui.T("g_openfolder"), false);
btnOpen.SetBounds(20, ph - 48, 170, 38);
btnOpen.Visible = false;
btnStop = new FlatButton(Ui.T("g_cancel"), false);
btnStop.SetBounds(clientW - 20 - 140, ph - 48, 140, 38);
pageWork.Controls.Add(btnOpen); pageWork.Controls.Add(btnStop);
btnOpen.Click += new EventHandler(OnOpenFolder);
btnStop.Click += new EventHandler(OnStopClick);
FormClosing += new FormClosingEventHandler(HandleClosing);
}
protected override void OnLoad(EventArgs e)
{
Scale(new SizeF(Theme.F, Theme.F));
CenterToScreen();
base.OnLoad(e);
}

protected override void OnHandleCreated(EventArgs e)
{
base.OnHandleCreated(e);
Glass.Apply(Handle);
AppIcon.Apply(this);
dpiScale = Theme.F;
}

internal Bitmap FrostImage { get { return frost; } }
protected void RefreshFrost()
{
try
{
Rectangle r = RectangleToScreen(ClientRectangle);
if (Opacity > 0.5)
{
double[] down = new double[] { 0.7, 0.4, 0.15 };
for (int i = 0; i < down.Length; i++) { Opacity = down[i]; Application.DoEvents(); Thread.Sleep(12); }
}
Opacity = 0;
Application.DoEvents();
Thread.Sleep(110);
Application.DoEvents();
Bitmap nb = Frost.Make(r);
if (frost != null) frost.Dispose();
frost = nb;
Invalidate(true);
Update();
double[] up = new double[] { 0.25, 0.5, 0.75, 0.9, 1.0 };
for (int i = 0; i < up.Length; i++) { Opacity = up[i]; Application.DoEvents(); Thread.Sleep(14); }
lastFrostPos = Location;
}
catch { try { Opacity = 1; } catch { } }
}

protected override void OnShown(EventArgs e)
{
base.OnShown(e);
RefreshFrost();
AppIcon.Apply(this);            // once more: the system sets its own icon while the window is being shown
Ui.HideOwnConsole();            // only now that the window is up: an earlier failure stays visible in the console
try { TopMost = true; TopMost = false; Activate(); } catch { }
}
protected override void WndProc(ref Message m)
{
base.WndProc(ref m);
if (m.Msg == 0x0232 && !busy && Location != lastFrostPos) RefreshFrost();
}

protected override void OnPaintBackground(PaintEventArgs e)
{
if (frost != null) e.Graphics.DrawImage(frost, 0, 0, frost.Width, frost.Height);
else Backdrop.Draw(e.Graphics, new Rectangle(0, 0, ClientSize.Width, ClientSize.Height));
}

protected override void OnPaint(PaintEventArgs e)
{
base.OnPaint(e);
Graphics g = e.Graphics;
g.SmoothingMode = SmoothingMode.AntiAlias;
g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
g.ScaleTransform(dpiScale, dpiScale);        // the header is drawn in 96 dpi units, the controls are scaled by Windows
Rectangle dot = new Rectangle(24, 22, 28, 28);
using (GraphicsPath p = Theme.Round(dot, 8))
using (LinearGradientBrush b = new LinearGradientBrush(dot, Theme.Accent, Theme.Accent2, 45f))
g.FillPath(b, p);
using (Pen pen = new Pen(Color.White, 2f))
{
g.DrawRectangle(pen, 33, 34, 10, 8);
g.DrawArc(pen, 34, 27, 8, 10, 180, 180);
}
g.ResetTransform();
using (SolidBrush b = new SolidBrush(Theme.Text)) g.DrawString("SecureEncrypt", Theme.Title, b, 62 * dpiScale, 12 * dpiScale);
using (SolidBrush b = new SolidBrush(Color.FromArgb(214, 220, 234))) g.DrawString(subtitle, Theme.Sub, b, 64 * dpiScale, 43 * dpiScale);
}

protected override void OnKeyDown(KeyEventArgs e)
{
if (e.KeyCode == Keys.Escape && !busy) { Close(); e.Handled = true; }
base.OnKeyDown(e);
}
protected virtual void KeepState() { }

private void OnLangClick(object s, EventArgs e)
{
if (busy) return;
ContextMenuStrip m = new ContextMenuStrip();
m.Renderer = new ToolStripProfessionalRenderer(new DarkColors());
m.BackColor = Color.FromArgb(30, 33, 46);
m.ForeColor = Theme.Text;
m.Font = Theme.Body;
for (int i = 0; i < Ui.LangCodes.Length; i++)
{
ToolStripMenuItem it = new ToolStripMenuItem(Ui.LangNames[i]);
it.ForeColor = Theme.Text;
string code = Ui.LangCodes[i];
it.Checked = code == Ui.LangCurrent;
it.Click += new EventHandler(delegate
{
if (code == Ui.LangCurrent || busy) return;
KeepState();
Ui.LangRequest = code;
Close();
});
m.Items.Add(it);
}
m.Show(btnLang, new Point(0, btnLang.Height + 2));
}

internal void ShowWork()
{
if (btnLang != null) btnLang.Enabled = false;
if (tabBar != null) tabBar.Enabled = false;
pageOpts.Visible = false;
if (pageAlt != null) pageAlt.Visible = false;
pageWork.Visible = true;
summary.Visible = false;
btnOpen.Visible = false;
btnStop.Text = Ui.T("g_cancel");
btnStop.Enabled = true;
bar.Value = 0;
status.ForeColor = Theme.Text;
status.Text = Ui.T("g_working");
}

internal void HookSinks()
{
SE.ProgressBar.CancelRequested = false;
Core.ConflictMode = 0;
SE.ProgressBar.Sink = new ProgressHandler(delegate(string label, int pct)
{
try { BeginInvoke(new MethodInvoker(delegate { bar.Value = pct; status.Text = label.Trim() + "  " + pct + "%"; })); } catch { }
});
Core.StatusSink = new StatusHandler(delegate(string text)
{
try { BeginInvoke(new MethodInvoker(delegate { status.Text = text; })); } catch { }
});
}

internal void UnhookSinks()
{
SE.ProgressBar.Sink = null;
Core.StatusSink = null;
Core.ConflictSink = null;
}
internal void ShowResult(bool ok, string statusText, string summaryText, string target)
{
busy = false;
openTarget = target;
bar.Value = ok ? 100 : bar.Value;
status.ForeColor = ok ? Theme.Ok : Theme.Danger;
status.Text = statusText;
if (summaryText != null && summaryText.Length > 0) { summary.Text = summaryText; summary.Visible = true; }
btnOpen.Visible = target != null;
btnStop.Text = Ui.T("g_close");
btnStop.Enabled = true;
if (ok) Ui.LastOk = true;
}

protected virtual void OnOpenFolder(object s, EventArgs e)
{
try
{
if (openTarget == null) return;
if (File.Exists(openTarget)) Process.Start("explorer.exe", "/select,\"" + openTarget + "\"");
else Process.Start("explorer.exe", "\"" + openTarget + "\"");
}
catch { }
}

private void OnStopClick(object s, EventArgs e)
{
if (busy) { SE.ProgressBar.CancelRequested = true; btnStop.Enabled = false; return; }
Close();
}

protected virtual void HandleClosing(object s, FormClosingEventArgs e)
{
if (busy) { SE.ProgressBar.CancelRequested = true; e.Cancel = true; }
}

internal Label MakeLabel(Control parent, string text, int x, int y, int w, Font f, Color c)
{
Label l = new Label();
l.Text = text;
l.SetBounds(x, y, w, 20);
l.BackColor = Color.Transparent; l.ForeColor = c; l.Font = f;
parent.Controls.Add(l);
return l;
}

internal void Warn(string text)
{
MessageBox.Show(this, text, Text, MessageBoxButtons.OK, MessageBoxIcon.Warning);
}

internal bool Confirm(string text)
{
return MessageBox.Show(this, text, Text, MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes;
}
}

internal class EncryptForm : GlassForm
{
private string head;
private ItemList list;
private Field pw1, pw2, kf;
private Label strength;
private Segmented del;
private FlatButton btnAddF, btnAddD, btnRem, btnKf, btnGo, btnCancel;
private Segmented tabs;
private DecryptPanel dec;

public EncryptForm(string[] items, string head) : base(Ui.T("g_title_enc"), Ui.T("g_sub_enc"), 900, 540)
{
this.head = head;
AllowDrop = true;
Card a = new Card(); a.SetBounds(20, 0, 420, 268); pageOpts.Controls.Add(a);
a.Controls.Add(new Caption(Ui.T("g_items"), 18, 12, 384));
list = new ItemList(); list.SetBounds(18, 36, 384, 170); list.AllowDrop = true;
a.Controls.Add(list);
btnAddF = new FlatButton(Ui.T("g_add_files"), false); btnAddF.SetBounds(18, 214, 120, 36);
btnAddD = new FlatButton(Ui.T("g_add_folder"), false); btnAddD.SetBounds(150, 214, 120, 36);
btnRem = new FlatButton(Ui.T("g_remove"), false); btnRem.SetBounds(282, 214, 120, 36);
a.Controls.Add(btnAddF); a.Controls.Add(btnAddD); a.Controls.Add(btnRem);

Card b = new Card(); b.SetBounds(452, 0, 428, 268); pageOpts.Controls.Add(b);
b.Controls.Add(new Caption(Ui.T("g_pw"), 18, 12, 230));
strength = MakeLabel(b, "", 250, 12, 160, Theme.Small, Theme.Dim);
strength.TextAlign = ContentAlignment.TopRight;
pw1 = new Field(true); pw1.SetBounds(18, 34, 392, 36); b.Controls.Add(pw1);
b.Controls.Add(new Caption(Ui.T("g_pw2"), 18, 78, 392));
pw2 = new Field(true); pw2.SetBounds(18, 100, 392, 36); b.Controls.Add(pw2);
b.Controls.Add(new Caption(Ui.T("g_kf"), 18, 144, 392));
kf = new Field(false); kf.SetBounds(18, 166, 280, 36); b.Controls.Add(kf);
btnKf = new FlatButton(Ui.T("g_browse"), false); btnKf.SetBounds(306, 166, 104, 36); b.Controls.Add(btnKf);
Label pwHint = MakeLabel(b, Ui.T("g_pw_hint"), 18, 208, 392, Theme.Small, Theme.Dim);
pwHint.Height = 54;

Card c = new Card(); c.SetBounds(20, 280, 860, 78); pageOpts.Controls.Add(c);
c.Controls.Add(new Caption(Ui.T("g_del"), 18, 10, 824));
del = new Segmented(new string[] { Ui.T("g_del0"), Ui.T("g_del1"), Ui.T("g_del2") });
del.SetBounds(18, 32, 824, 34); c.Controls.Add(del);

Label note = MakeLabel(pageOpts, Ui.T("dont_forget"), 24, 364, 852, Theme.Small, Theme.Warn);
note.Height = 40;                        // two lines of the small font plus a margin (longer translations wrap too)

btnCancel = new FlatButton(Ui.T("g_cancel"), false); btnCancel.SetBounds(630, 410, 110, 38);
btnGo = new FlatButton(Ui.T("g_encrypt"), true); btnGo.SetBounds(750, 410, 130, 38);
pageOpts.Controls.Add(btnCancel); pageOpts.Controls.Add(btnGo);
pageAlt = new Backdrop();
pageAlt.SetBounds(0, HeaderH, 900, 540 - HeaderH);
pageAlt.Visible = false;
Controls.Add(pageAlt);
dec = new DecryptPanel(this, pageAlt, true, null, 0);
tabs = new Segmented(new string[] { Ui.T("g_encrypt"), Ui.T("g_decrypt") });
tabs.SetBounds(360, 18, 250, 34);
tabBar = tabs;
Controls.Add(tabs);
tabs.Changed += new EventHandler(delegate { ShowTab(tabs.SelectedIndex); });
if (items != null && items.Length == 1 && Ui.KeptTab == 0 && Ui.KeptDecFile.Length == 0 && items[0] != null
&& items[0].Trim().Trim('"').EndsWith("_decrypt.cmd", StringComparison.OrdinalIgnoreCase)
&& File.Exists(items[0].Trim().Trim('"')))
{
Ui.KeptDecFile = items[0].Trim().Trim('"');
Ui.KeptTab = 1;
items = null;
}
if (items != null) for (int i = 0; i < items.Length; i++) AddItem(items[i]);
ShowRefused();
if (Ui.KeptDecFile.Length > 0) dec.SetFile(Ui.KeptDecFile);
if (Ui.KeptTab == 1) { tabs.SelectedIndex = 1; ShowTab(1); }
Ui.KeptTab = 0; Ui.KeptDecFile = "";

DragEnter += new DragEventHandler(OnDragEnter);
DragDrop += new DragEventHandler(OnDragDrop);
list.DragEnter += new DragEventHandler(OnDragEnter);
list.DragDrop += new DragEventHandler(OnDragDrop);
btnAddF.Click += new EventHandler(OnAddFiles);
btnAddD.Click += new EventHandler(OnAddFolder);
btnRem.Click += new EventHandler(OnRemove);
btnKf.Click += new EventHandler(OnBrowseKf);
pw1.Box.TextChanged += new EventHandler(OnPwChanged);
btnGo.Click += new EventHandler(OnGo);
btnCancel.Click += new EventHandler(delegate { Close(); });
}

protected override void OnKeyDown(KeyEventArgs e)
{
if (e.KeyCode == Keys.Enter && pageOpts.Visible && !busy) { btnGo.PerformClick(); e.Handled = true; e.SuppressKeyPress = true; }
else if (e.KeyCode == Keys.Enter && pageAlt.Visible && !busy) { dec.Go(); e.Handled = true; e.SuppressKeyPress = true; }
base.OnKeyDown(e);
}

private void ShowTab(int i)
{
pageOpts.Visible = i == 0;
pageAlt.Visible = i == 1;
subtitle = Ui.T(i == 0 ? "g_sub_enc" : "g_sub_dec");
Text = Ui.T(i == 0 ? "g_title_enc" : "g_title_dec");
Invalidate();
}

protected override void HandleClosing(object s, FormClosingEventArgs e)
{
base.HandleClosing(s, e);
if (!e.Cancel) dec.Dispose();
}

protected override void KeepState()
{
string[] items = new string[list.Items.Count];
for (int i = 0; i < items.Length; i++) items[i] = (string)list.Items[i];
Ui.KeptItems = items;
Ui.KeptTab = tabs.SelectedIndex;
Ui.KeptDecFile = dec.SelectedFile;
}

private void AddItem(string p)
{
if (string.IsNullOrEmpty(p)) return;
p = p.Trim().Trim('"');
if (p.Length == 0) return;
if (!File.Exists(p) && !Directory.Exists(p)) return;
string full = Path.GetFullPath(p);
if (full.Length > 3) full = full.TrimEnd('\\');
if (Ui.Forbidden(full)) { refused.Add(full); return; }
for (int i = 0; i < list.Items.Count; i++)
if (string.Equals((string)list.Items[i], full, StringComparison.OrdinalIgnoreCase)) return;
list.Items.Add(full);
}
private List<string> refused = new List<string>();

private void ShowRefused()
{
if (refused.Count == 0) return;
StringBuilder sb = new StringBuilder(Ui.T("forbidden"));
sb.Append("\r\n");
for (int i = 0; i < refused.Count && i < 12; i++) sb.Append("\r\n").Append(refused[i]);
if (refused.Count > 12) sb.Append("\r\n...");
refused.Clear();
Warn(sb.ToString());
}

private void OnDragEnter(object s, DragEventArgs e)
{
if (!busy && e.Data.GetDataPresent(DataFormats.FileDrop)) e.Effect = DragDropEffects.Copy;
else e.Effect = DragDropEffects.None;
}

private void OnDragDrop(object s, DragEventArgs e)
{
if (busy) return;
string[] files = (string[])e.Data.GetData(DataFormats.FileDrop);
if (pageAlt.Visible)
{
if (files != null && files.Length > 0) dec.SetFile(files[0]);
return;
}
if (files != null) for (int i = 0; i < files.Length; i++) AddItem(files[i]);
ShowRefused();
}

private void OnAddFiles(object s, EventArgs e)
{
OpenFileDialog d = new OpenFileDialog();
d.Multiselect = true;
d.CheckFileExists = true;
if (d.ShowDialog(this) == DialogResult.OK)
{
for (int i = 0; i < d.FileNames.Length; i++) AddItem(d.FileNames[i]);
ShowRefused();
}
}

private void OnAddFolder(object s, EventArgs e)
{
string[] picked = FolderPicker.Pick(Handle, Ui.T("g_add_folder").TrimEnd('.'));
if (picked != null)
{
for (int i = 0; i < picked.Length; i++) AddItem(picked[i]);
ShowRefused();
return;
}
FolderBrowserDialog d = new FolderBrowserDialog();
if (d.ShowDialog(this) == DialogResult.OK) { AddItem(d.SelectedPath); ShowRefused(); }
}

private void OnRemove(object s, EventArgs e)
{
for (int i = list.SelectedIndices.Count - 1; i >= 0; i--) list.Items.RemoveAt(list.SelectedIndices[i]);
}

private void OnBrowseKf(object s, EventArgs e)
{
string f = Ui.PickFile(this, Ui.T("kf_pick_title"));
if (f != null) kf.Text = f;
}

private int StrengthOf(string pw)
{
SecureString ss = Ui.ToSecure(pw);
int n = Core.Strength(ss);
ss.Dispose();
if (n < 0) n = 0;
if (n > 4) n = 4;
return n;
}

private void OnPwChanged(object s, EventArgs e)
{
if (pw1.Text.Length == 0) { strength.Text = ""; return; }
int n = StrengthOf(pw1.Text);
strength.Text = Ui.TF("pw_strength", Ui.T("strength" + n), null);
strength.ForeColor = n <= 1 ? Theme.Danger : (n == 2 ? Theme.Warn : Theme.Ok);
}

private void OnGo(object s, EventArgs e)
{
if (busy) return;
if (list.Items.Count == 0) { Warn(Ui.T("empty")); return; }

string p1 = pw1.Text;
if (p1.Length > 0)
{
if (p1 != pw2.Text) { Warn(Ui.T("pw_mismatch")); return; }
if (StrengthOf(p1) <= 1 && !Confirm(Ui.T("pw_weak"))) return;
}
string kfPath = kf.Text.Trim().Trim('"');
if (kfPath.Length > 0 && !File.Exists(kfPath)) { Warn(Ui.TF("kf_missing", kfPath, null)); return; }
if (p1.Length == 0 && kfPath.Length == 0)
{
if (!Confirm(Ui.T("no_enc") + "\r\n\r\n" + Ui.T("g_continue"))) return;
}

string[] items = new string[list.Items.Count];
for (int i = 0; i < items.Length; i++) items[i] = (string)list.Items[i];

string first = items[0];
string leaf = Path.GetFileName(first.TrimEnd('\\'));
if (string.IsNullOrEmpty(leaf)) leaf = "Drive_" + first.Substring(0, 1);
string baseName = File.Exists(first) ? Path.GetFileNameWithoutExtension(leaf) : leaf;
if (items.Length > 1) baseName = string.Format("{0}_and_{1}_more", baseName, items.Length - 1);
string outDir = Path.GetDirectoryName(first.TrimEnd('\\'));
if (string.IsNullOrEmpty(outDir)) outDir = first;
string outCmd = Path.Combine(outDir, baseName + "_decrypt.cmd");
if (File.Exists(outCmd) && !Confirm(Ui.TF("exists_q", outCmd, null))) return;

SecureString pw = Ui.ToSecure(p1);
byte[] secret;
try { secret = Core.MakeSecret(pw, kfPath.Length > 0 ? Path.GetFullPath(kfPath) : null); }
catch (Exception ex) { Warn(Ui.ErrorText(ex)); return; }
finally { pw.Dispose(); }
pw1.Text = ""; pw2.Text = "";

int delMode = del.SelectedIndex;
bool usesPw = p1.Length > 0;
bool usesKf = kfPath.Length > 0;
bool gzip = true;
if (items.Length == 1 && File.Exists(first))
{
string ext = Path.GetExtension(first).ToLowerInvariant();
for (int i = 0; i < Ui.CompressedExt.Length; i++) if (Ui.CompressedExt[i] == ext) gzip = false;
}
if (gzip && Core.TotalSize(items, Core.GzipLimit) >= Core.GzipLimit) gzip = false;

busy = true;
ShowWork();
HookSinks();
Thread t = new Thread(new ThreadStart(delegate { Work(items, outCmd, gzip, secret, usesPw, usesKf, delMode); }));
t.Start();
}

private void Work(string[] items, string outCmd, bool gzip, byte[] secret, bool usesPw, bool usesKf, int delMode)
{
string part = outCmd + ".part";
string error = null;
string text = null;
bool ok = false;
Stopwatch sw = Stopwatch.StartNew();
try
{
if (File.Exists(outCmd)) { File.SetAttributes(outCmd, FileAttributes.Normal); File.Delete(outCmd); }
if (File.Exists(part)) File.Delete(part);
File.WriteAllText(part, head, Encoding.ASCII);

Core.Encode(items, part, outCmd, gzip, secret, usesPw, usesKf, Core.DefaultIterations, delMode > 0);
File.Move(part, outCmd);
File.SetAttributes(outCmd, FileAttributes.ReadOnly);
sw.Stop();

StringBuilder sb = new StringBuilder();
sb.AppendLine(Ui.TF("src_info", Core.LastCount, Ui.FmtSize(Core.LastTotal)));
sb.AppendLine(Ui.TF("src_sha", Core.LastSha, null));
string mode = secret == null ? Ui.T("mode1") : Ui.T("mode2");
mode += ", " + (gzip ? Ui.T("comp_on") : Ui.T("comp_off"));
sb.AppendLine(Ui.TF("mode_label", mode, null));
for (int i = 0; i < Core.Skipped.Count; i++) sb.AppendLine(Ui.TF("skipped", Core.Skipped[i], null));
if (delMode > 0) sb.AppendLine(Ui.T("verified"));
sb.AppendLine(Ui.TF("out_info", outCmd, Ui.FmtSize(Core.LastOutSize)));
if (Core.LastOutSize >= 4294967296L) sb.AppendLine(Ui.T("big_warn"));
sb.AppendLine(Ui.TF("elapsed", Ui.FmtDuration(sw.Elapsed.TotalSeconds), null));

if (delMode > 0)
{
bool inside = false;
for (int i = 0; i < items.Length; i++)
if (Directory.Exists(items[i]) && outCmd.StartsWith(items[i].TrimEnd('\\') + "\\", StringComparison.OrdinalIgnoreCase)) inside = true;
if (inside || Core.Skipped.Count > 0) sb.AppendLine(Ui.T("del_skip"));
else
{
try
{
Core.DeleteItems(items, delMode == 2);
if (Core.DeleteFailed.Count == 0) sb.AppendLine(Ui.T("del_ok"));
else
{
sb.AppendLine(Ui.TF("del_partial", Core.DeleteFailed.Count, null));
for (int i = 0; i < Core.DeleteFailed.Count; i++) sb.AppendLine("  " + Core.DeleteFailed[i]);
sb.AppendLine(Ui.T("del_partial_hint"));
}
}
catch (Exception dx) { sb.AppendLine(Ui.TF("del_fail", dx.Message, null)); }
}
}
text = sb.ToString();
ok = true;
}
catch (Exception ex)
{
try { if (File.Exists(part)) File.Delete(part); } catch { }
error = Ui.ErrorText(ex);
}
finally
{
if (secret != null) Array.Clear(secret, 0, secret.Length);
UnhookSinks();
}

try
{
BeginInvoke(new MethodInvoker(delegate
{
if (ok) ShowResult(true, Ui.T("success"), text, outCmd);
else ShowResult(false, error, null, null);
}));
}
catch { }
}

}

internal class SetupForm : GlassForm
{
public SetupForm(bool installed, string message, bool messageOk) : base(Ui.T("g_title_setup"), Ui.T("g_sub_setup"), 404)
{
Card a = new Card(); a.SetBounds(20, 0, 580, 132); pageOpts.Controls.Add(a);
a.Controls.Add(new Caption(Ui.T("g_st_cap"), 18, 12, 544));
Label st = MakeLabel(a, installed ? Ui.T("g_st_yes") : Ui.T("g_st_no"), 18, 34, 340, Theme.Title, installed ? Theme.Ok : Theme.Warn);
st.Height = 40;
FlatButton free = new FlatButton(Ui.T("g_btn_free"), false);
int dw = (int)Math.Ceiling(TextRenderer.MeasureText(Ui.T("g_btn_free"), Theme.Bold).Width / Theme.F) + 44;
if (dw < 150) dw = 150;
if (dw > 280) dw = 280;
free.SetBounds(580 - 24 - dw, 27, dw, 36);
st.Width = 580 - 24 - dw - 18 - 8;
a.Controls.Add(free);
free.Click += new EventHandler(delegate { Ui.SetupAction = 3; Close(); });
Label hint = MakeLabel(a, Ui.T("use_hint1") + " " + Ui.T("use_hint2"), 18, 76, 544, Theme.Body, Theme.Dim);
hint.Height = 44;

Card b = new Card(); b.SetBounds(20, 144, 580, 112); pageOpts.Controls.Add(b);
Label what = MakeLabel(b, Ui.T("install_menu"), 18, 14, 544, Theme.Body, Theme.Text);
what.Height = 40;
Label msg = MakeLabel(b, message == null ? "" : message, 18, 62, 544, Theme.Bold, messageOk ? Theme.Ok : Theme.Danger);
msg.Height = 40;

FlatButton un = new FlatButton(Ui.T("g_btn_uninstall"), false);
un.SetBounds(20, 272, 150, 38);
un.Enabled = installed;
FlatButton close = new FlatButton(Ui.T("g_close"), false);
close.SetBounds(300, 272, 100, 38);
FlatButton go = new FlatButton(installed ? Ui.T("g_btn_update") : Ui.T("g_btn_install"), true);
go.SetBounds(410, 272, 190, 38);
pageOpts.Controls.Add(un); pageOpts.Controls.Add(close); pageOpts.Controls.Add(go);

go.Click += new EventHandler(delegate { Ui.SetupAction = 1; Close(); });
un.Click += new EventHandler(delegate
{
if (Confirm(Ui.T("g_confirm_un"))) { Ui.SetupAction = 2; Close(); }
});
close.Click += new EventHandler(delegate { Close(); });
ActiveControl = go;
}
}
internal class DecryptPanel
{
private GlassForm host;
private bool picker;
private Archive arc;
private string dest;
private string selected = "";
private Field pw, kf, fileBox;
private Label info;
private FlatButton btnKf, btnGo, btnCancel, btnPick;
private int attempts;
private bool checking;

internal string SelectedFile { get { return selected; } }

public DecryptPanel(GlassForm host, Panel page, bool picker, string selfPath, long dataStart)
{
this.host = host;
this.picker = picker;
int rowH = picker ? 268 : 180;
Card a = new Card(); a.SetBounds(20, 0, 420, rowH); page.Controls.Add(a);
Card b = new Card(); b.SetBounds(452, 0, 428, rowH); page.Controls.Add(b);

if (picker)
{
a.Controls.Add(new Caption(Ui.T("g_dec_pick"), 18, 12, 384));
fileBox = new Field(false); fileBox.SetBounds(18, 36, 384, 36);
fileBox.Box.ReadOnly = true; fileBox.Box.TabStop = false; fileBox.TabStop = false;
a.Controls.Add(fileBox);
btnPick = new FlatButton(Ui.T("g_dec_choose"), false); btnPick.SetBounds(18, 82, 170, 36);
a.Controls.Add(btnPick);
Label hint = host.MakeLabel(a, Ui.T("g_dec_hint"), 18, 132, 384, Theme.Small, Theme.Dim);
hint.Height = 80;
Card c = new Card(); c.SetBounds(20, 280, 860, 78); page.Controls.Add(c);
info = host.MakeLabel(c, "", 18, 14, 824, Theme.Bold, Theme.Text);
info.Height = 54;
}
else
{
a.Controls.Add(new Caption(Ui.TF("file", Path.GetFileName(selfPath), null), 18, 12, 384));
info = host.MakeLabel(a, "", 18, 40, 384, Theme.Bold, Theme.Text);
info.Height = 120;
}

b.Controls.Add(new Caption(Ui.T(picker ? "g_dec_pw" : "t_pw"), 18, 12, 392));
pw = new Field(true); pw.SetBounds(18, 34, 392, 36); b.Controls.Add(pw);
b.Controls.Add(new Caption(Ui.T(picker ? "g_dec_kf" : "g_kf"), 18, 84, 392));
kf = new Field(false); kf.SetBounds(18, 108, 280, 36);
btnKf = new FlatButton(Ui.T("g_browse"), false); btnKf.SetBounds(306, 108, 104, 36);
b.Controls.Add(kf); b.Controls.Add(btnKf);

int by = picker ? 410 : 196;
btnCancel = new FlatButton(Ui.T("g_cancel"), false); btnCancel.SetBounds(630, by, 110, 38);
btnGo = new FlatButton(Ui.T("g_decrypt"), true); btnGo.SetBounds(750, by, 130, 38);
page.Controls.Add(btnCancel); page.Controls.Add(btnGo);

btnKf.Click += new EventHandler(OnBrowseKf);
btnGo.Click += new EventHandler(OnGo);
btnCancel.Click += new EventHandler(delegate { host.Close(); });
if (picker) btnPick.Click += new EventHandler(OnPick);

if (picker)
{
info.ForeColor = Theme.Dim;
info.Text = Ui.T("g_dec_none");
pw.Enabled = false; kf.Enabled = false; btnKf.Enabled = false; btnGo.Enabled = false;
}
else Load(selfPath, dataStart);
}

internal void Go() { btnGo.PerformClick(); }

internal void Dispose()
{
if (arc != null) arc.Clear();
}
private void Load(string path, long dataStart)
{
Archive na = Archive.Open(path, dataStart);
if (arc != null) arc.Clear();
arc = na;
dest = Path.GetDirectoryName(path);
attempts = 0;
pw.Text = ""; kf.Text = "";
info.ForeColor = Theme.Text;
btnGo.Enabled = true;
btnCancel.Text = Ui.T("g_cancel");
if (arc.Mode != 2)
{
info.Text = Ui.T("enc_none");
pw.Enabled = false; kf.Enabled = false; btnKf.Enabled = false;
}
else
{
string n;
if (arc.UsesPassword && arc.UsesKeyFile) n = Ui.T("n_both");
else if (arc.UsesKeyFile) n = Ui.T("n_kf");
else n = Ui.T("n_pw");
info.Text = Ui.TF("needs", n, null);
pw.Enabled = arc.UsesPassword;
kf.Enabled = arc.UsesKeyFile;
btnKf.Enabled = arc.UsesKeyFile;
}
}
internal void SetFile(string p)
{
if (host.busy || checking || string.IsNullOrEmpty(p)) return;
try
{
p = p.Trim().Trim('"');
if (!File.Exists(p)) return;
string full = Path.GetFullPath(p);
long ds = FindDataStart(full);
if (ds < 0) { host.Warn(Ui.T("g_dec_bad")); return; }
Load(full, ds);
selected = full;
fileBox.Text = full;
fileBox.Box.Select(0, 0);
}
catch (Exception ex) { host.Warn(Ui.ErrorText(ex)); }
}
private static long FindDataStart(string path)
{
byte[] buf = new byte[262144];
int n;
using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite)) n = fs.Read(buf, 0, buf.Length);
string txt = Encoding.GetEncoding(28591).GetString(buf, 0, n);
int e = txt.IndexOf("#PS_" + "END" + "\r\n", StringComparison.Ordinal);
if (e < 0) return -1;
return e + 9;
}

private void OnPick(object s, EventArgs e)
{
OpenFileDialog d = new OpenFileDialog();
d.Title = Ui.T("g_dec_choose").TrimEnd('.');
d.CheckFileExists = true;
d.Multiselect = false;
d.Filter = "*_decrypt.cmd|*_decrypt.cmd|*.cmd|*.cmd";
if (d.ShowDialog(host) == DialogResult.OK) SetFile(d.FileName);
}

private void OnBrowseKf(object s, EventArgs e)
{
string f = Ui.PickFile(host, Ui.T("kf_pick_title"));
if (f != null) kf.Text = f;
}

private void OnGo(object s, EventArgs e)
{
if (arc == null || host.busy || checking || attempts >= 3) return;
byte[] secret = null;
if (arc.Mode == 2)
{
string kfPath = null;
if (arc.UsesKeyFile)
{
string k = kf.Text.Trim().Trim('"');
if (k.Length == 0 || !File.Exists(k)) { host.Warn(Ui.TF("kf_missing", k, null)); return; }
kfPath = Path.GetFullPath(k);
}
SecureString ss = Ui.ToSecure(arc.UsesPassword ? pw.Text : "");
bool unlocked;
checking = true;
btnGo.Enabled = false;
host.Cursor = Cursors.WaitCursor;
info.ForeColor = Theme.Dim;
info.Text = Ui.T("kdf");
info.Refresh();
Core.StatusSink = new StatusHandler(delegate(string x) { });
try
{
secret = Core.MakeSecret(ss, kfPath);
unlocked = secret != null && arc.Unlock(secret);
}
catch (Exception ex)
{
info.ForeColor = Theme.Danger;
info.Text = Ui.ErrorText(ex);
return;
}
finally { ss.Dispose(); host.Cursor = Cursors.Default; Core.StatusSink = null; checking = false; btnGo.Enabled = attempts < 3; }
if (!unlocked)
{
if (secret != null) Array.Clear(secret, 0, secret.Length);
attempts++;
pw.Text = "";
info.ForeColor = Theme.Danger;
info.Text = Ui.TF("wrong", attempts, 3);
if (attempts >= 3)
{
btnGo.Enabled = false; pw.Enabled = false; kf.Enabled = false; btnKf.Enabled = false;
info.Text = Ui.T("g_toomany");
btnCancel.Text = Ui.T("g_close");
host.Warn(Ui.T("g_toomany"));
}
return;
}
pw.Text = "";
}

host.busy = true;
host.ShowWork();
host.HookSinks();
Core.ConflictSink = new ConflictHandler(delegate(string target)
{
int r = 0;
try { host.Invoke(new MethodInvoker(delegate { r = Ui.AskConflict(host, target); })); } catch { }
return r;
});
Thread t = new Thread(new ThreadStart(delegate { Work(secret); }));
t.Start();
}

private void Work(byte[] secret)
{
string error = null;
string text = null;
bool ok = false;
try
{
Stopwatch sw = Stopwatch.StartNew();
arc.Extract(dest);
sw.Stop();
StringBuilder sb = new StringBuilder();
sb.AppendLine(Ui.TF("sha", arc.ShaHex, null));
sb.AppendLine(arc.ShaOk ? Ui.T("sha_ok") : Ui.T("sha_fail"));
sb.AppendLine(Ui.TF("done", arc.Count, Path.GetFullPath(dest)));
sb.AppendLine(Ui.TF("elapsed", Ui.FmtDuration(sw.Elapsed.TotalSeconds), null));
text = sb.ToString();
ok = arc.ShaOk;
if (!ok) error = Ui.T("sha_fail");
}
catch (Exception ex) { error = Ui.ErrorText(ex); }
finally
{
if (secret != null) Array.Clear(secret, 0, secret.Length);
host.UnhookSinks();
}
try
{
host.BeginInvoke(new MethodInvoker(delegate
{
host.ShowResult(ok, ok ? Ui.T("g_done_dec") : error, text, dest);
}));
}
catch { }
}
}

internal class DecryptForm : GlassForm
{
private DecryptPanel panel;

public DecryptForm(string selfPath, long dataStart) : base(Ui.T("g_title_dec"), Ui.T("g_sub_dec"), 900, 330)
{
panel = new DecryptPanel(this, pageOpts, false, selfPath, dataStart);
}

protected override void OnKeyDown(KeyEventArgs e)
{
if (e.KeyCode == Keys.Enter && pageOpts.Visible && !busy) { panel.Go(); e.Handled = true; e.SuppressKeyPress = true; }
base.OnKeyDown(e);
}

protected override void HandleClosing(object s, FormClosingEventArgs e)
{
base.HandleClosing(s, e);
if (!e.Cancel) panel.Dispose();
}
}
}
'@

$DecSrc = @'
$ErrorActionPreference = 'Stop'
$Self = $env:SE_SELF
# Started hidden and detached by the stub: the extracted copy of this script removes itself (it is read completely by now).
if ($env:SE_DETACHED -eq '1') { try { Remove-Item -LiteralPath $MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue } catch { } }
# ---------------------------------------------------------------- texts
# The texts live in src\lang\*.ini; build.ps1 embeds them as $LangData (language code -> key -> text).
# Keys that a language lacks fall back to English. The same block is in engine.ps1 and dec.ps1.

$script:LangCode = 'en'

# order: SE_LANG, the language chosen in the window (saved), the Windows display language, English
function Get-LangCode {
    $c = $env:SE_LANG
    if (-not $c) {
        try {
            $rk = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\SecureEncrypt')
            if ($rk -ne $null) { $c = [string]$rk.GetValue('Language'); $rk.Close() }
        } catch { }
    }
    if (-not $c) { $c = [Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName }
    $c = ([string]$c).ToLower()
    if ($LangData.ContainsKey($c)) { return $c }
    return 'en'
}

function Set-Language([string]$code) {
    if (-not $LangData.ContainsKey($code)) { return }
    $script:LangCode = $code
    try {
        $rk = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\SecureEncrypt')
        $rk.SetValue('Language', $code)
        $rk.Close()
    } catch { }
}

function T([string]$k) {
    $v = $null
    if ($LangData.ContainsKey($script:LangCode)) { $v = $LangData[$script:LangCode][$k] }
    if ($v -eq $null) { $v = $LangData['en'][$k] }
    if ($v -eq $null) { return $k }
    return [regex]::Unescape($v)
}

# hands the texts and the language list to the window code (C#)
function Push-GuiStrings {
    foreach ($k in @($LangData['en'].Keys)) { [SE.UI.Ui]::Put($k, (T $k)) }
    $codes = @($LangData.Keys | Sort-Object)
    $names = @()
    foreach ($c in $codes) {
        $n = $LangData[$c]['lang_name']
        if ($n -eq $null) { $n = $c }
        $names += [regex]::Unescape($n)
    }
    [SE.UI.Ui]::SetLanguages([string[]]$codes, [string[]]$names, $script:LangCode)
}

$script:LangCode = Get-LangCode

# explicit parameters: `-f $args` misbehaves with 2+ values on PowerShell 2.0
function TF([string]$k, $a0, $a1) {
    return [string]::Format((T $k), $a0, $a1)
}

# A hidden (detached) run has no console to talk to: the text mode is shown in a new, visible console instead.
function Restart-Visible {
    $env:SE_GUI = '0'
    $env:SE_DETACHED = ''
    Start-Process -FilePath $env:ComSpec -ArgumentList ('/c ""' + $Self + '""')
}

function Wait-Key {
    if ($env:SE_DETACHED -eq '1') { Restart-Visible; exit 1 }
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
function Add-LibType([bool]$gui) {
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
        if ($gui) {
            Add-Type -TypeDefinition ($LibSrc + "`r`n" + $GuiSrc) -Language CSharp -ReferencedAssemblies 'System.Windows.Forms.dll', 'System.Drawing.dll'
        } else {
            Add-Type -TypeDefinition $LibSrc -Language CSharp
        }
    } finally {
        $env:TEMP = $oldTemp; $env:TMP = $oldTmp
    }
}

# window (GUI) mode is the default; SE_GUI=0 forces the text mode. It needs Windows Forms (not on Server Core).
$useGui = ($env:SE_GUI -ne '0')
if ($useGui) {
    try {
        if (-not [Environment]::UserInteractive -or [Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') -eq $null) { $useGui = $false }
    } catch { $useGui = $false }
}
# hidden run but no window possible (e.g. Server Core): continue in a visible console
if (-not $useGui -and $env:SE_DETACHED -eq '1') { Restart-Visible; exit 1 }

try {
    Add-LibType $useGui
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

    if ($useGui) {
        while ($true) {
            Push-GuiStrings
            $rc = [SE.UI.Ui]::Decrypt($Self, $dataStart)
            $req = [SE.UI.Ui]::LangRequest
            if ($req) { Set-Language $req; [SE.UI.Ui]::LangRequest = ''; continue }
            exit $rc
        }
    }

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


    $sw = [Diagnostics.Stopwatch]::StartNew()
    try { $arc.Extract($dest) }
    finally {
        $sw.Stop()
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
    Write-Host (TF 'elapsed' ([SE.UI.Ui]::FmtDuration($sw.Elapsed.TotalSeconds)))
    Write-Host (T 'footer')
    Wait-Key
    if ($arc.ShaOk) { exit 0 } else { exit 1 }
} catch {
    if ($env:SE_DETACHED -eq '1') { Restart-Visible; exit 1 }
    try { [SE.UI.Ui]::ShowOwnConsole() } catch { }
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

$ShellSrc = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Reflection;

[assembly: AssemblyTitle("SecureEncrypt Windows 11 context menu handler")]
[assembly: AssemblyDescription("SecureEncrypt Windows 11 context menu handler")]
[assembly: AssemblyCompany("Abdullah ERT\u00dcRK")]
[assembly: AssemblyProduct("SecureEncrypt")]
[assembly: AssemblyCopyright("Open source - Abdullah ERT\u00dcRK - github.com/abdullah-erturk - erturk-dev.netlify.app")]
[assembly: AssemblyVersion("7.0.0.0")]
[assembly: AssemblyFileVersion("7.0.0.0")]
[assembly: AssemblyInformationalVersion("7.0 -open source: github.com/abdullah-erturk - erturk-dev.netlify.app")]

namespace SEShell
{
[ComImport, Guid("43826d1e-e718-42ee-bc55-a1e261c37bfe"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IShellItem
{
void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppv);
void GetParent(out IShellItem ppsi);
void GetDisplayName(uint sigdnName, out IntPtr ppszName);
void GetAttributes(uint mask, out uint attr);
void Compare(IShellItem psi, uint hint, out int order);
}

[ComImport, Guid("b63ea76d-1f85-456f-a19c-48159efa858b"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IShellItemArray
{
void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppvOut);
void GetPropertyStore(int flags, ref Guid riid, out IntPtr ppv);
void GetPropertyDescriptionList(IntPtr keyType, ref Guid riid, out IntPtr ppv);
void GetAttributes(int attribFlags, uint sfgaoMask, out uint attribs);
void GetCount(out uint count);
void GetItemAt(uint index, out IShellItem item);
void EnumItems(out IntPtr enumItems);
}

[ComImport, Guid("a08ce4d0-fa25-44ab-b57c-c7b1c323e0b9"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IExplorerCommand
{
[PreserveSig] int GetTitle(IShellItemArray items, [MarshalAs(UnmanagedType.LPWStr)] out string name);
[PreserveSig] int GetIcon(IShellItemArray items, [MarshalAs(UnmanagedType.LPWStr)] out string icon);
[PreserveSig] int GetToolTip(IShellItemArray items, [MarshalAs(UnmanagedType.LPWStr)] out string tip);
[PreserveSig] int GetCanonicalName(out Guid guid);
[PreserveSig] int GetState(IShellItemArray items, [MarshalAs(UnmanagedType.Bool)] bool okToBeSlow, out uint state);
[PreserveSig] int Invoke(IShellItemArray items, IntPtr bindCtx);
[PreserveSig] int GetFlags(out uint flags);
[PreserveSig] int EnumSubCommands(out IntPtr enumCommands);
}

[ComImport, Guid("a88826f8-186f-4987-aade-ea0cef8fbfe8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IEnumExplorerCommand
{
[PreserveSig] int Next(uint celt, [Out, MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.Interface, SizeParamIndex = 0)] IExplorerCommand[] commands, out uint fetched);
[PreserveSig] int Skip(uint celt);
[PreserveSig] int Reset();
[PreserveSig] int Clone(out IEnumExplorerCommand clone);
}

[ComImport, Guid("00000001-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IClassFactory
{
[PreserveSig] int CreateInstance(IntPtr outer, ref Guid riid, out IntPtr obj);
[PreserveSig] int LockServer([MarshalAs(UnmanagedType.Bool)] bool lockServer);
}

[ComImport, Guid("FC4801A3-2BA9-11CF-A229-00AA003D7352"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IObjectWithSite
{
[PreserveSig] int SetSite([MarshalAs(UnmanagedType.IUnknown)] object site);
[PreserveSig] int GetSite(ref Guid riid, out IntPtr site);
}

static class SiteInfo
{
public static bool IsClassicMenu(object site)
{
if (site == null) return false;
IntPtr unk = IntPtr.Zero, p = IntPtr.Zero;
try
{
unk = Marshal.GetIUnknownForObject(site);
Guid g = new Guid("000214E4-0000-0000-C000-000000000046");     // IContextMenu
if (Marshal.QueryInterface(unk, ref g, out p) == 0) { Marshal.Release(p); return true; }
}
catch { }
finally { if (unk != IntPtr.Zero) Marshal.Release(unk); }
return false;
}
}

static class Util
{
public static DateTime Last = DateTime.UtcNow;
public static void Touch() { Last = DateTime.UtcNow; }

public static List<string> Paths(IShellItemArray items)
{
List<string> r = new List<string>();
if (items == null) return r;
uint n;
items.GetCount(out n);
for (uint i = 0; i < n; i++)
{
IShellItem it;
items.GetItemAt(i, out it);
IntPtr p;
it.GetDisplayName(0x80058000, out p);                  // SIGDN_FILESYSPATH
string s = Marshal.PtrToStringUni(p);
Marshal.FreeCoTaskMem(p);
if (!string.IsNullOrEmpty(s)) r.Add(s);
}
return r;
}
public static string Label(int line, string fallback)
{
try
{
string f = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "labels.txt");
if (File.Exists(f))
{
string[] l = File.ReadAllLines(f, Encoding.UTF8);
if (l.Length > line && l[line].Trim().Length > 0) return l[line].Trim();
}
}
catch { }
return fallback;
}
public static string IconPath()
{
string f = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "SecureEncrypt.ico");
if (File.Exists(f)) return f;
return Environment.GetFolderPath(Environment.SpecialFolder.System) + "\\imageres.dll,54";
}

public static string Target()
{
return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "SecureEncrypt.cmd");
}
}

[ComVisible(true), ClassInterface(ClassInterfaceType.None)]
class EncryptCommand : IExplorerCommand
{
public int GetTitle(IShellItemArray items, out string name) { Util.Touch(); name = Util.Label(0, "Encrypt (Secure Encrypt AES-256)"); return 0; }
public int GetIcon(IShellItemArray items, out string icon) { icon = Util.IconPath(); return 0; }
public int GetToolTip(IShellItemArray items, out string tip) { tip = null; return unchecked((int)0x80004001); }
public int GetCanonicalName(out Guid guid) { guid = Guid.Empty; return unchecked((int)0x80004001); }
public int GetState(IShellItemArray items, bool okToBeSlow, out uint state) { Util.Touch(); state = 0; return 0; }
public int GetFlags(out uint flags) { flags = 0; return 0; }
public int EnumSubCommands(out IntPtr e) { e = IntPtr.Zero; return unchecked((int)0x80004001); }

public int Invoke(IShellItemArray items, IntPtr bindCtx)
{
Util.Touch();
try
{
List<string> paths = Util.Paths(items);
if (paths.Count == 0) return 0;
string q = Path.Combine(Path.GetTempPath(), "SecureEncrypt_queue");
Directory.CreateDirectory(q);
string list = Path.Combine(q, "list_" + DateTime.UtcNow.Ticks + "_" + Guid.NewGuid().ToString("N").Substring(0, 6) + ".txt");
File.WriteAllText(list, string.Join("\r\n", paths.ToArray()), Encoding.Unicode);
ProcessStartInfo psi = new ProcessStartInfo(Util.Target(), "/list \"" + list + "\"");
psi.UseShellExecute = true;
Process.Start(psi);
}
catch { }
return 0;
}
}

[ComVisible(true), ClassInterface(ClassInterfaceType.None)]
class DecryptCommand : IExplorerCommand
{
public int GetTitle(IShellItemArray items, out string name) { Util.Touch(); name = Util.Label(1, "Decrypt (Secure Encrypt AES-256)"); return 0; }
public int GetIcon(IShellItemArray items, out string icon) { icon = Util.IconPath(); return 0; }
public int GetToolTip(IShellItemArray items, out string tip) { tip = null; return unchecked((int)0x80004001); }
public int GetCanonicalName(out Guid guid) { guid = Guid.Empty; return unchecked((int)0x80004001); }
public int GetFlags(out uint flags) { flags = 0; return 0; }
public int EnumSubCommands(out IntPtr e) { e = IntPtr.Zero; return unchecked((int)0x80004001); }
public int GetState(IShellItemArray items, bool okToBeSlow, out uint state)
{
Util.Touch();
state = 2;                                                  // ECS_HIDDEN
try
{
List<string> p = Util.Paths(items);
if (p.Count == 1 && p[0].EndsWith("_decrypt.cmd", StringComparison.OrdinalIgnoreCase)) state = 0;
}
catch { }
return 0;
}

public int Invoke(IShellItemArray items, IntPtr bindCtx)
{
Util.Touch();
try
{
List<string> p = Util.Paths(items);
if (p.Count != 1) return 0;
ProcessStartInfo psi = new ProcessStartInfo(p[0]);
psi.UseShellExecute = true;
psi.WorkingDirectory = Path.GetDirectoryName(p[0]);
Process.Start(psi);
}
catch { }
return 0;
}
}
[ComVisible(true), ClassInterface(ClassInterfaceType.None)]
class OpenCommand : IExplorerCommand
{
public int GetTitle(IShellItemArray items, out string name) { Util.Touch(); name = Util.Label(2, "Open the SecureEncrypt window"); return 0; }
public int GetIcon(IShellItemArray items, out string icon) { icon = Util.IconPath(); return 0; }
public int GetToolTip(IShellItemArray items, out string tip) { tip = null; return unchecked((int)0x80004001); }
public int GetCanonicalName(out Guid guid) { guid = Guid.Empty; return unchecked((int)0x80004001); }
public int GetState(IShellItemArray items, bool okToBeSlow, out uint state) { Util.Touch(); state = 0; return 0; }
public int GetFlags(out uint flags) { flags = 0x20; return 0; }       // ECF_SEPARATORBEFORE
public int EnumSubCommands(out IntPtr e) { e = IntPtr.Zero; return unchecked((int)0x80004001); }

public int Invoke(IShellItemArray items, IntPtr bindCtx)
{
Util.Touch();
try
{
ProcessStartInfo psi = new ProcessStartInfo(Util.Target(), "/gui");
psi.UseShellExecute = true;
Process.Start(psi);
}
catch { }
return 0;
}
}

[ComVisible(true), ClassInterface(ClassInterfaceType.None)]
class SubEnum : IEnumExplorerCommand
{
private IExplorerCommand[] list;
private int pos;
public SubEnum(IExplorerCommand[] l, int p) { list = l; pos = p; }

public int Next(uint celt, IExplorerCommand[] commands, out uint fetched)
{
Util.Touch();
uint n = 0;
while (n < celt && pos < list.Length) { commands[n] = list[pos]; n++; pos++; }
fetched = n;
return n == celt ? 0 : 1;                                   // S_FALSE when fewer were left
}
public int Skip(uint celt) { pos += (int)celt; return pos <= list.Length ? 0 : 1; }
public int Reset() { pos = 0; return 0; }
public int Clone(out IEnumExplorerCommand clone) { clone = new SubEnum(list, pos); return 0; }
}
[ComVisible(true), ClassInterface(ClassInterfaceType.None)]
class ParentCommand : IExplorerCommand, IObjectWithSite
{
private bool classic;
public int SetSite(object site) { Util.Touch(); classic = SiteInfo.IsClassicMenu(site); return 0; }
public int GetSite(ref Guid riid, out IntPtr site) { site = IntPtr.Zero; return unchecked((int)0x80004002); }
public int GetTitle(IShellItemArray items, out string name) { Util.Touch(); name = "SecureEncrypt"; return 0; }
public int GetIcon(IShellItemArray items, out string icon) { icon = Util.IconPath(); return 0; }
public int GetToolTip(IShellItemArray items, out string tip) { tip = null; return unchecked((int)0x80004001); }
public int GetCanonicalName(out Guid guid) { guid = Guid.Empty; return unchecked((int)0x80004001); }
public int GetState(IShellItemArray items, bool okToBeSlow, out uint state) { Util.Touch(); state = classic ? 2u : 0u; return 0; }   // ECS_HIDDEN in the old menu
public int Invoke(IShellItemArray items, IntPtr bindCtx) { return 0; }
public int GetFlags(out uint flags) { flags = 1; return 0; }       // ECF_HASSUBCOMMANDS

public int EnumSubCommands(out IntPtr enumCommands)
{
Util.Touch();
SubEnum e = new SubEnum(new IExplorerCommand[] { new EncryptCommand(), new DecryptCommand(), new OpenCommand() }, 0);
enumCommands = Marshal.GetComInterfaceForObject(e, typeof(IEnumExplorerCommand));
return 0;
}
}

class Factory : IClassFactory
{
private Type type;
public Factory(Type t) { type = t; }

public int CreateInstance(IntPtr outer, ref Guid riid, out IntPtr obj)
{
Util.Touch();
obj = IntPtr.Zero;
if (outer != IntPtr.Zero) return unchecked((int)0x80040110);          // CLASS_E_NOAGGREGATION
object o = Activator.CreateInstance(type);
IntPtr unk = Marshal.GetIUnknownForObject(o);
try { return Marshal.QueryInterface(unk, ref riid, out obj); }
finally { Marshal.Release(unk); }
}

public int LockServer(bool l) { Util.Touch(); return 0; }
}

static class Program
{
[DllImport("ole32.dll")]
static extern int CoRegisterClassObject(ref Guid rclsid, [MarshalAs(UnmanagedType.Interface)] IClassFactory pUnk, uint context, uint flags, out uint cookie);
[DllImport("ole32.dll")]
static extern int CoRevokeClassObject(uint cookie);

static readonly Guid ParentId = new Guid("5D3A7C61-2B4E-4F0A-9E1D-7A9B6C3E8F10");

static int Main(string[] args)
{
bool embedding = false;
for (int i = 0; i < args.Length; i++) if (args[i].IndexOf("Embedding", StringComparison.OrdinalIgnoreCase) >= 0) embedding = true;
if (!embedding) return 0;                                              // started by hand: nothing to do

uint c1;
Guid g1 = ParentId;
int h1 = CoRegisterClassObject(ref g1, new Factory(typeof(ParentCommand)), 4, 1, out c1);   // LOCAL_SERVER, MULTIPLEUSE
if (h1 != 0) return 1;
Util.Touch();
while ((DateTime.UtcNow - Util.Last).TotalSeconds < 30) Thread.Sleep(500);
CoRevokeClassObject(c1);
return 0;
}
}
}
'@

$PackSrc = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;

public static class ShellPack
{
[DllImport("shell32.dll")]
private static extern void SHChangeNotify(int eventId, uint flags, IntPtr item1, IntPtr item2);
public static void NotifyShell()
{
SHChangeNotify(0x08000000, 0, IntPtr.Zero, IntPtr.Zero);
}
private static Bitmap Draw(int px)
{
Bitmap bmp = new Bitmap(px, px, PixelFormat.Format32bppArgb);
using (Graphics g = Graphics.FromImage(bmp))
{
g.SmoothingMode = SmoothingMode.AntiAlias;
g.Clear(Color.Transparent);
g.ScaleTransform(px / 28f, px / 28f);
GraphicsPath p = new GraphicsPath();
p.AddArc(0, 0, 16, 16, 180, 90); p.AddArc(12, 0, 16, 16, 270, 90);
p.AddArc(12, 12, 16, 16, 0, 90); p.AddArc(0, 12, 16, 16, 90, 90);
p.CloseFigure();
using (LinearGradientBrush b = new LinearGradientBrush(new Rectangle(0, 0, 28, 28), Color.FromArgb(99, 102, 241), Color.FromArgb(56, 189, 248), 45f))
g.FillPath(b, p);
using (Pen pen = new Pen(Color.White, 2f))
{
g.DrawRectangle(pen, 9, 12, 10, 8);
g.DrawArc(pen, 10, 5, 8, 10, 180, 180);
}
}
return bmp;
}

private static byte[] Png(int px)
{
using (Bitmap b = Draw(px))
using (MemoryStream ms = new MemoryStream())
{
b.Save(ms, ImageFormat.Png);
return ms.ToArray();
}
}
public static void WriteIco(string path)
{
int[] sizes = new int[] { 16, 20, 24, 32, 40, 48, 64 };
List<byte[]> images = new List<byte[]>();
foreach (int n in sizes)
{
byte[] pix = new byte[n * n * 4];
using (Bitmap b = Draw(n))
{
BitmapData d = b.LockBits(new Rectangle(0, 0, n, n), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
byte[] row = new byte[n * 4];
for (int y = 0; y < n; y++)
{
Marshal.Copy(new IntPtr(d.Scan0.ToInt64() + (long)y * d.Stride), row, 0, n * 4);
Array.Copy(row, 0, pix, (n - 1 - y) * n * 4, n * 4);
}
b.UnlockBits(d);
}
int maskRow = ((n + 31) / 32) * 4;
using (MemoryStream ms = new MemoryStream())
using (BinaryWriter w = new BinaryWriter(ms))
{
w.Write((uint)40); w.Write(n); w.Write(n * 2); w.Write((ushort)1); w.Write((ushort)32); w.Write((uint)0);
w.Write((uint)(pix.Length + maskRow * n)); w.Write(0); w.Write(0); w.Write((uint)0); w.Write((uint)0);
w.Write(pix);
w.Write(new byte[maskRow * n]);
images.Add(ms.ToArray());
}
}
using (FileStream fs = new FileStream(path, FileMode.Create))
using (BinaryWriter w = new BinaryWriter(fs))
{
w.Write((ushort)0); w.Write((ushort)1); w.Write((ushort)sizes.Length);
int offset = 6 + 16 * sizes.Length;
for (int i = 0; i < sizes.Length; i++)
{
w.Write((byte)sizes[i]); w.Write((byte)sizes[i]); w.Write((byte)0); w.Write((byte)0);
w.Write((ushort)1); w.Write((ushort)32); w.Write((uint)images[i].Length); w.Write((uint)offset);
offset += images[i].Length;
}
foreach (byte[] im in images) w.Write(im);
}
}
public static string Build(string workDir, string manifestText)
{
UTF8Encoding utf8 = new UTF8Encoding(false);
MsixWriter w = new MsixWriter();
w.Add("AppxManifest.xml", utf8.GetBytes(manifestText));
w.Add("Assets/StoreLogo.png", Png(50));
w.Add("Assets/Square44x44Logo.png", Png(44));
w.Add("Assets/Square150x150Logo.png", Png(150));
w.Add("AppxBlockMap.xml", utf8.GetBytes(w.BlockMap()));
string ct = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"png\" ContentType=\"image/png\" /><Override PartName=\"/AppxManifest.xml\" ContentType=\"application/vnd.ms-appx.manifest+xml\" /><Override PartName=\"/AppxBlockMap.xml\" ContentType=\"application/vnd.ms-appx.blockmap+xml\" /></Types>";
w.Add("[Content_Types].xml", utf8.GetBytes(ct));
string path = Path.Combine(workDir, "SecureEncrypt.msix");
w.Save(path);
return path;
}
}
class MsixWriter
{
private class Entry { public string Name; public byte[] Data; public uint Crc; public uint Offset; }
private List<Entry> entries = new List<Entry>();
private static uint[] table;

private static uint Crc32(byte[] d)
{
if (table == null)
{
table = new uint[256];
for (uint i = 0; i < 256; i++)
{
uint c = i;
for (int k = 0; k < 8; k++) c = (c & 1) != 0 ? 0xEDB88320u ^ (c >> 1) : c >> 1;
table[i] = c;
}
}
uint crc = 0xFFFFFFFFu;
for (int i = 0; i < d.Length; i++) crc = table[(crc ^ d[i]) & 0xFF] ^ (crc >> 8);
return ~crc;
}

public void Add(string name, byte[] data)
{
Entry e = new Entry();
e.Name = name; e.Data = data; e.Crc = Crc32(data);
entries.Add(e);
}
public string BlockMap()
{
StringBuilder sb = new StringBuilder();
sb.Append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r\n<BlockMap xmlns=\"http://schemas.microsoft.com/appx/2010/blockmap\" HashMethod=\"http://www.w3.org/2001/04/xmlenc#sha256\">");
foreach (Entry e in entries)
{
int lfh = 30 + Encoding.UTF8.GetByteCount(e.Name);
sb.Append("<File Name=\"" + e.Name.Replace('/', '\\') + "\" Size=\"" + e.Data.Length + "\" LfhSize=\"" + lfh + "\">");
for (int off = 0; off < e.Data.Length; off += 65536)
{
int len = Math.Min(65536, e.Data.Length - off);
byte[] blk = new byte[len];
Array.Copy(e.Data, off, blk, 0, len);
sb.Append("<Block Hash=\"" + Convert.ToBase64String(SHA256.Create().ComputeHash(blk)) + "\" />");
}
sb.Append("</File>");
}
sb.Append("</BlockMap>");
return sb.ToString();
}

public void Save(string path)
{
using (FileStream fs = new FileStream(path, FileMode.Create))
using (BinaryWriter w = new BinaryWriter(fs))
{
foreach (Entry e in entries)
{
e.Offset = (uint)fs.Position;
byte[] n = Encoding.UTF8.GetBytes(e.Name);
w.Write((uint)0x04034b50); w.Write((ushort)20); w.Write((ushort)0x0800); w.Write((ushort)0); w.Write((ushort)0); w.Write((ushort)0x21);
w.Write(e.Crc); w.Write((uint)e.Data.Length); w.Write((uint)e.Data.Length); w.Write((ushort)n.Length); w.Write((ushort)0);
w.Write(n); w.Write(e.Data);
}
uint cdStart = (uint)fs.Position;
foreach (Entry e in entries)
{
byte[] n = Encoding.UTF8.GetBytes(e.Name);
w.Write((uint)0x02014b50); w.Write((ushort)20); w.Write((ushort)20); w.Write((ushort)0x0800); w.Write((ushort)0); w.Write((ushort)0); w.Write((ushort)0x21);
w.Write(e.Crc); w.Write((uint)e.Data.Length); w.Write((uint)e.Data.Length); w.Write((ushort)n.Length);
w.Write((ushort)0); w.Write((ushort)0); w.Write((ushort)0); w.Write((ushort)0); w.Write((uint)0); w.Write(e.Offset); w.Write(n);
}
uint cdSize = (uint)fs.Position - cdStart;
w.Write((uint)0x06054b50); w.Write((ushort)0); w.Write((ushort)0); w.Write((ushort)entries.Count); w.Write((ushort)entries.Count);
w.Write(cdSize); w.Write(cdStart); w.Write((ushort)0);
}
}
}
'@

$ManifestSrc = @'
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
         xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
         xmlns:uap10="http://schemas.microsoft.com/appx/manifest/uap/windows10/10"
         xmlns:desktop4="http://schemas.microsoft.com/appx/manifest/desktop/windows10/4"
         xmlns:desktop5="http://schemas.microsoft.com/appx/manifest/desktop/windows10/5"
         xmlns:com="http://schemas.microsoft.com/appx/manifest/com/windows10"
         xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
         IgnorableNamespaces="uap uap10 desktop4 desktop5 com rescap">
  <Identity Name="AbdullahErturk.SecureEncrypt" Publisher="CN=Abdullah Erturk, OID.2.25.311729368913984317654407730594956997722=1" Version="1.0.0.0" ProcessorArchitecture="neutral" />
  <Properties>
    <DisplayName>SecureEncrypt</DisplayName>
    <PublisherDisplayName>Abdullah Erturk</PublisherDisplayName>
    <Logo>Assets\StoreLogo.png</Logo>
    <uap10:AllowExternalContent>true</uap10:AllowExternalContent>
  </Properties>
  <Resources>
    <Resource Language="en-us" />
  </Resources>
  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.19041.0" MaxVersionTested="10.0.22621.0" />
  </Dependencies>
  <Capabilities>
    <rescap:Capability Name="runFullTrust" />
  </Capabilities>
  <Applications>
    <Application Id="SecureEncrypt" Executable="SecureEncryptShell.exe" uap10:TrustLevel="mediumIL" uap10:RuntimeBehavior="win32App">
      <uap:VisualElements AppListEntry="none" DisplayName="SecureEncrypt" Description="SecureEncrypt context menu" BackgroundColor="transparent" Square150x150Logo="Assets\Square150x150Logo.png" Square44x44Logo="Assets\Square44x44Logo.png" />
      <Extensions>
        <desktop4:Extension Category="windows.fileExplorerContextMenus">
          <desktop4:FileExplorerContextMenus>
            <desktop5:ItemType Type="*">
              <desktop5:Verb Id="SecureEncryptModern" Clsid="5D3A7C61-2B4E-4F0A-9E1D-7A9B6C3E8F10" />
            </desktop5:ItemType>
            <desktop5:ItemType Type="Directory">
              <desktop5:Verb Id="SecureEncryptModern" Clsid="5D3A7C61-2B4E-4F0A-9E1D-7A9B6C3E8F10" />
            </desktop5:ItemType>          </desktop4:FileExplorerContextMenus>
        </desktop4:Extension>
        <com:Extension Category="windows.comServer">
          <com:ComServer>
            <com:ExeServer Executable="SecureEncryptShell.exe" Arguments="-Embedding" DisplayName="SecureEncrypt context menu">
              <com:Class Id="5D3A7C61-2B4E-4F0A-9E1D-7A9B6C3E8F10" DisplayName="SecureEncrypt" />

            </com:ExeServer>
          </com:ComServer>
        </com:Extension>
      </Extensions>
    </Application>
  </Applications>
</Package>
'@


# ---------------------------------------------------------------- entry point

function Run-Main($argList) {
    $script:LangCode = Get-LangCode
    $a = @($argList)
    $queue = $false
    $late = $false
    # window mode is the default when there are items to encrypt; /console (or SE_GUI=0) forces the text mode,
    # /gui opens the window even without items. The install menu and the right-click fallback queue stay text based.
    $guiMode = 'auto'
    if ($env:SE_GUI -eq '0') { $guiMode = 'off' } elseif ($env:SE_GUI -eq '1') { $guiMode = 'on' }
    while ($a.Count -gt 0 -and ($a[0] -eq '/q' -or $a[0] -eq '/late' -or $a[0] -eq '/gui' -or $a[0] -eq '/console')) {
        if ($a[0] -eq '/q') { $queue = $true } elseif ($a[0] -eq '/late') { $late = $true } elseif ($a[0] -eq '/gui') { $guiMode = 'on' } else { $guiMode = 'off' }
        if ($a.Count -gt 1) { $a = @($a[1..($a.Count - 1)]) } else { $a = @() }
    }
    # started by the window with elevated rights to install / uninstall (see Invoke-SetupAction)
    if ($a.Count -ge 2 -and $a[0] -eq '/elevated') {
        if (-not (Test-Admin)) { exit 1 }
        $target = Join-Path $env:SystemRoot 'SecureEncrypt.cmd'
        if ($a[1] -eq 'install') { Do-Install $target }
        elseif ($a[1] -eq 'uninstall') { Do-Uninstall $target }
        return
    }
    # the right-click helper passes the paths in a Unicode list file (file names may contain %VARIABLE% patterns)
    if ($a.Count -ge 2 -and $a[0] -eq '/list') {
        $listFile = $a[1]
        $lines = @()
        try { $lines = [IO.File]::ReadAllLines($listFile, [Text.Encoding]::Unicode) }
        finally { try { Remove-Item -LiteralPath $listFile -Force } catch { } }
        $a = @($lines | Where-Object { $_.Trim().Length -gt 0 })
    }
    $script:RunItems = @($a)
    # hidden run but no window possible (e.g. Server Core): continue in a visible console
    if ($env:SE_DETACHED -eq '1' -and ($guiMode -eq 'off' -or -not (Test-GuiAvailable))) { Restart-Visible $a; return }
    if ($a.Count -eq 0 -and $guiMode -ne 'on') { Show-InstallMenu ($guiMode -ne 'off' -and (Test-GuiAvailable)); return }
    if ($queue) { $a = @(Wait-Queue $a[0]) }
    if ($guiMode -ne 'off' -and (Test-GuiAvailable)) {
        try {
            Invoke-EncryptGui ([string[]]$a) $late
            return
        } catch {
            # the window could not be shown: say why and continue in the text mode with the same items
            if ($env:SE_DETACHED -eq '1') { if ($script:GuiItems) { Restart-Visible $script:GuiItems } else { Restart-Visible $a }; return }
            try { [SE.UI.Ui]::ShowOwnConsole() } catch { }
            Write-Host (TF 'err' $_.Exception.Message) -ForegroundColor Yellow
            Write-Host
            if ($script:GuiItems) { $a = @($script:GuiItems); $late = $false }
        }
    }
    try {
        Invoke-Encrypt ([string[]]$a) $late
    } finally {
        if ($late) { Remove-LeaderLock }
    }
}

try {
    Run-Main $args
} catch {
    if ($env:SE_DETACHED -eq '1') { Restart-Visible $script:RunItems; exit 1 }
    try { [SE.UI.Ui]::ShowOwnConsole() } catch { }
    Write-Host
    Write-Host (TF 'err' $_.Exception.Message) -ForegroundColor Red
    Wait-Key
    exit 1
}
