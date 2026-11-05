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

#@@EMBED@@

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
