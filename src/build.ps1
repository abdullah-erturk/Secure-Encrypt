# Builds SecureEncrypt.cmd from the parts in this folder and computes its integrity signature.
#
#   SecureEncrypt.cmd is a GENERATED file. To change the code, edit the parts in src\ and run this script:
#       launcher.bat  integrity check + starts the PowerShell program
#       engine.ps1    menus, prompts, install / uninstall
#       lib.cs        crypto and archive core (also embedded in every *_decrypt.cmd)
#       gui.cs        window (GUI) mode, Windows Forms (only compiled when the window is used)
#       lang\*.ini    the texts, one file per language (en.ini is the base); all of them are embedded
#       dec.ps1       the decryptor that is embedded in every *_decrypt.cmd
#       stub.bat      batch start-up part of every *_decrypt.cmd
#       ext\          optional Windows 11 context menu entry: COM server, icon / package builder, package manifest
#       shim.js.txt   right-click helper (multi selection -> one window; JScript source, stored as .txt)
#   Usage:  powershell -File src\build.ps1 [output path]
param([string]$Out = (Join-Path (Split-Path -Parent $PSScriptRoot) 'SecureEncrypt.cmd'), [switch]$NoPause)
$ErrorActionPreference = 'Stop'

# Keeps the window open when the script was started by double-click / "Run with PowerShell" (parent = Explorer),
# so the messages can be read. From a terminal it returns immediately. -NoPause disables it.
function Wait-IfDoubleClicked {
    if ($NoPause) { return }
    $fromExplorer = $true
    try {
        $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$PID" | ForEach-Object { Get-CimInstance Win32_Process -Filter "ProcessId=$($_.ParentProcessId)" }
        if ($parent -and $parent.Name -ne 'explorer.exe') { $fromExplorer = $false }
    } catch { }
    if ($fromExplorer) {
        Write-Host
        Write-Host 'Press any key to close this window...'
        try { [void][Console]::ReadKey($true) } catch { }
    }
}
try {
    $d = Split-Path -Parent $MyInvocation.MyCommand.Path

    Write-Host 'SecureEncrypt build'
    Write-Host '-------------------'
    Write-Host "Sources : $d"
    Write-Host "Output  : $Out"
    Write-Host

    function ReadSrc($n) {
        $f = Join-Path $d $n
        if (-not (Test-Path -LiteralPath $f)) { throw "Missing source file: $f" }
        Write-Host ('  read    {0,-13} {1,7:N0} bytes' -f $n, (Get-Item -LiteralPath $f).Length)
        [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8)
    }

    Write-Host '[1/4] Reading the parts'
    $engine   = ReadSrc 'engine.ps1'
    $launcher = ReadSrc 'launcher.bat'
    # lib.cs is shrunk (no comment lines, no indentation) because a copy travels inside every *_decrypt.cmd
    $lib      = (ReadSrc 'lib.cs') -replace '(?m)^\s*//.*\r?\n', '' -replace '(?m)^[ ]+', ''
    $gui      = (ReadSrc 'gui.cs') -replace '(?m)^\s*//.*\r?\n', '' -replace '(?m)^[ ]+', ''
    $dec      = ReadSrc 'dec.ps1'
    $stub     = ReadSrc 'stub.bat'
    $shim     = ReadSrc 'shim.js.txt'
    # optional Windows 11 context menu entry (COM server, icon / package builder, package manifest)
    $shellSrc = (ReadSrc 'ext\shell_server.cs') -replace '(?m)^\s*//.*\r?\n', '' -replace '(?m)^[ ]+', ''
    $packSrc  = (ReadSrc 'ext\shell_pack.cs') -replace '(?m)^\s*//.*\r?\n', '' -replace '(?m)^[ ]+', ''
    $manifest = ReadSrc 'ext\AppxManifest.xml'

    # ---- language files: src\lang\<code>.ini  ->  $LangData (code -> key -> text)
    $langDir = Join-Path $d 'lang'
    $langFiles = @()
    if (Test-Path -LiteralPath $langDir) { $langFiles = @(Get-ChildItem -LiteralPath $langDir -Filter '*.ini' | Sort-Object Name) }
    if (-not ($langFiles | Where-Object { $_.Name -eq 'en.ini' })) { throw "Missing language file: $langDir\en.ini (English is the base language)" }
    $Langs = @{}
    foreach ($f in $langFiles) {
        $code = $f.BaseName.ToLower()
        if ($code -notmatch '^[a-z]{2,8}(-[a-z0-9]{2,8})?$') { throw "Bad language file name '$($f.Name)' (use a language code such as en.ini, tr.ini, de.ini)" }
        $secs = @{ common = @{}; app = @{}; decrypt = @{} }
        $cur = $null; $n = 0
        foreach ($line in [IO.File]::ReadAllLines($f.FullName, [Text.Encoding]::UTF8)) {
            $n++
            $l = $line.Trim()
            if ($l.Length -eq 0 -or $l.StartsWith(';') -or $l.StartsWith('#')) { continue }
            if ($l -match '^\[(\w+)\]$') {
                $cur = $Matches[1].ToLower()
                if (-not $secs.ContainsKey($cur)) { throw "$($f.Name) line ${n}: unknown section [$cur] (use [common], [app] or [decrypt])" }
                continue
            }
            $i = $l.IndexOf('=')
            if ($i -lt 1 -or $cur -eq $null) { throw "$($f.Name) line ${n}: expected 'key = value' inside a [section]" }
            $key = $l.Substring(0, $i).Trim()
            $val = $l.Substring($i + 1).Trim()
            if ($key -notmatch '^[A-Za-z0-9_]+$') { throw "$($f.Name) line ${n}: bad key '$key' (letters, digits and _ only)" }
            if ($val.Length -ge 2 -and $val.StartsWith('"') -and $val.EndsWith('"')) { $val = $val.Substring(1, $val.Length - 2) }
            if ($secs[$cur].ContainsKey($key)) { throw "$($f.Name) line ${n}: key '$key' appears twice in [$cur]" }
            $secs[$cur][$key] = $val
        }
        $Langs[$code] = $secs
    }
    function Merge-Lang($secs, $side) {
        $m = @{}
        foreach ($k in $secs['common'].Keys) { $m[$k] = $secs['common'][$k] }
        foreach ($k in $secs[$side].Keys) { $m[$k] = $secs[$side][$k] }
        return $m
    }
    function Emit-Lang($side) {
        $o = New-Object Text.StringBuilder
        [void]$o.Append("`$LangData = @{`n")
        foreach ($code in @($Langs.Keys | Sort-Object)) {
            [void]$o.Append("    '$code' = @{`n")
            $m = Merge-Lang $Langs[$code] $side
            foreach ($k in @($m.Keys | Sort-Object)) {
                $v = $m[$k].Replace('\', '\\').Replace("'", "''")
                [void]$o.Append("        '$k' = '$v'`n")
            }
            [void]$o.Append("    }`n")
        }
        [void]$o.Append('}')
        return $o.ToString()
    }
    Write-Host '  languages:'
    foreach ($side in 'app', 'decrypt') {
        $base = Merge-Lang $Langs['en'] $side
        foreach ($code in @($Langs.Keys | Sort-Object)) {
            $m = Merge-Lang $Langs[$code] $side
            $missing = @($base.Keys | Where-Object { -not $m.ContainsKey($_) })
            $extra = @($m.Keys | Where-Object { -not $base.ContainsKey($_) })
            $msg = '    {0,-6} {1,-8} {2,3} texts' -f $code, "[$side]", $m.Count
            if ($missing.Count -gt 0) { $msg += "   missing $($missing.Count) (English is used): " + (($missing | Select-Object -First 5) -join ', ') + $(if ($missing.Count -gt 5) { ' ...' }) }
            if ($extra.Count -gt 0) { $msg += "   unknown keys ignored by the program: " + (($extra | Select-Object -First 5) -join ', ') }
            Write-Host $msg
        }
    }

    # every *_decrypt.cmd carries the decoder, the window code and the decrypt texts of all languages in its text part;
    # the decrypt stub reads only the first 256 KB of the file to find it
    $headSize = $lib.Length + $gui.Length + $dec.Length + $stub.Length + (Emit-Lang 'decrypt').Length
    Write-Host ('  text part of every *_decrypt.cmd: about {0:N0} KB (limit 256 KB)' -f ($headSize / 1KB))
    if ($headSize -gt 245000) { throw 'The text part of *_decrypt.cmd would exceed the 256 KB limit. Too many languages or too much text.' }

    Write-Host '[2/4] Assembling'
    function Here($name, $text) { "`$$name = @'`n" + $text.TrimEnd() + "`n'@`n" }
    $embed  = (Emit-Lang 'app') + "`n`n" + (Here 'LangDecSrc' (Emit-Lang 'decrypt')) + "`n" + (Here 'LibSrc' $lib) + "`n" + (Here 'GuiSrc' $gui) + "`n" + (Here 'DecSrc' $dec) + "`n" + (Here 'StubSrc' $stub) + "`n" + (Here 'ShimSrc' $shim) + "`n" + (Here 'ShellSrc' $shellSrc) + "`n" + (Here 'PackSrc' $packSrc) + "`n" + (Here 'ManifestSrc' $manifest)
    $engine = $engine.Replace('#@@EMBED@@', $embed)
    # The launcher extracts the program with `more +N` (much faster than starting PowerShell just for that).
    # N is the line number of the marker comment; `more` skips N lines or starts at line N, and either way only
    # the harmless marker comment can be involved.
    $launcherText = $launcher.TrimEnd()
    $markerLine = ($launcherText -split "`r?`n").Count + 1
    $full   = $launcherText.Replace('__PSLINE__', [string]$markerLine) + "`n#@@" + "PS`n" + $engine
    # everything non-ASCII becomes a \uXXXX escape (only the Turkish text table uses them; it is un-escaped at runtime)
    $sb = New-Object Text.StringBuilder
    foreach ($ch in $full.ToCharArray()) { if ([int]$ch -gt 127) { [void]$sb.Append(('\u{0:x4}' -f [int]$ch)) } else { [void]$sb.Append($ch) } }
    $full = $sb.ToString().Replace("`r", '').Replace("`n", "`r`n")
    if ($full.Contains("`t")) { throw 'Tabs are not allowed in the sources (more.com expands them and the signature would not match).' }

    Write-Host '[3/4] Computing the SHA256 signature (same method as the launcher: more +10 | certutil)'
    $tmp = "$Out.build"
    [IO.File]::WriteAllText($tmp, $full.Replace('__SIG__', ('0' * 64)), [Text.Encoding]::ASCII)
    cmd /c "more +10 `"$tmp`" > `"$tmp.region`""
    $h = (certutil -hashfile "$tmp.region" SHA256 | Select-Object -Skip 1 -First 1).Trim().Replace(' ', '')
    Remove-Item "$tmp.region"
    [IO.File]::WriteAllText($tmp, $full.Replace('__SIG__', $h), [Text.Encoding]::ASCII)

    Write-Host '[4/4] Writing the output'
    if (Test-Path -LiteralPath $Out) { attrib -R $Out; Remove-Item -LiteralPath $Out -Force }
    Move-Item -LiteralPath $tmp -Destination $Out

    # ---- browser version: web\index.html (a single static page; the Windows decryptor head is embedded so that
    # files encrypted in the browser are normal *_decrypt.cmd files)
    $tplPath = Join-Path $d 'web\template.html'
    if (Test-Path -LiteralPath $tplPath) {
        function Norm($s) {
            $b = New-Object Text.StringBuilder
            foreach ($ch in $s.ToCharArray()) { if ([int]$ch -gt 127) { [void]$b.Append(('\u{0:x4}' -f [int]$ch)) } else { [void]$b.Append($ch) } }
            return $b.ToString().Replace("`r", '').Replace("`n", "`r`n")
        }
        $nl = "`r`n"
        $decPs = (Norm (Emit-Lang 'decrypt').TrimEnd()) + $nl + '$LibSrc = @' + "'" + $nl + (Norm $lib.TrimEnd()) + $nl + "'@" + $nl + '$GuiSrc = @' + "'" + $nl + (Norm $gui.TrimEnd()) + $nl + "'@" + $nl + (Norm $dec.TrimEnd())
        $headText = (Norm $stub.TrimEnd()) + $nl + '#PS_' + 'BEGIN' + $nl + $decPs + $nl + '#PS_' + 'END' + $nl
        $headBytes = [Text.Encoding]::ASCII.GetBytes($headText)
        $ms = New-Object IO.MemoryStream
        $gz = New-Object IO.Compression.GZipStream($ms, [IO.Compression.CompressionMode]::Compress)
        $gz.Write($headBytes, 0, $headBytes.Length); $gz.Close()
        $headB64 = [Convert]::ToBase64String($ms.ToArray())
        $tpl = [IO.File]::ReadAllText($tplPath, [Text.Encoding]::UTF8)
        $webOut = Join-Path (Split-Path -Parent $Out) 'web\index.html'
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $webOut))
        [IO.File]::WriteAllText($webOut, $tpl.Replace('@@HEAD@@', $headB64), (New-Object Text.UTF8Encoding($false)))
        $webHash = (certutil -hashfile $webOut SHA256 | Select-Object -Skip 1 -First 1).Trim().Replace(' ', '')
        Write-Host ('  web page  : {0}  ({1:N0} bytes)' -f $webOut, (Get-Item -LiteralPath $webOut).Length)
        Write-Host ('  web sha256: {0}' -f $webHash)
    }

    Write-Host
    Write-Host 'Build finished.' -ForegroundColor Green
    Write-Host ('  file      : {0}' -f $Out)
    Write-Host ('  size      : {0:N0} bytes' -f (Get-Item -LiteralPath $Out).Length)
    Write-Host ('  signature : {0}' -f $h)
    Write-Host
    Write-Host 'Reminder: SecureEncrypt.cmd alone is enough to USE the program; src\ is only needed to CHANGE it.'
    Write-Host 'Edit the parts in src\ and run build.ps1 again; do not edit SecureEncrypt.cmd by hand.'
    Write-Host 'Installed copies (right-click menu) and existing *_decrypt.cmd files are not updated automatically.'
} catch {
    Write-Host
    Write-Host ('BUILD FAILED: ' + $_.Exception.Message) -ForegroundColor Red
    Wait-IfDoubleClicked
    exit 1
}
Wait-IfDoubleClicked
