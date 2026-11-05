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
