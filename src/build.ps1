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
param([string]$Out = '', [switch]$NoPause)
$ErrorActionPreference = 'Stop'
# default output: SecureEncrypt.cmd next to src\ ($PSScriptRoot does not exist in scripts of PowerShell 2.0 / Windows 7, so $MyInvocation is used)
if (-not $Out) { $Out = Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) 'SecureEncrypt.cmd' }

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
    # the program version lives only in engine.ps1 ($Version = 'x.y'); the window code gets it where it says @@VERSION@@
    $verMatch = [regex]::Match($engine, "(?m)^\`$Version\s*=\s*'([^']+)'")
    if (-not $verMatch.Success) { throw 'engine.ps1: $Version not found' }
    $progVer  = $verMatch.Groups[1].Value
    $gui      = ((ReadSrc 'gui.cs') -replace '(?m)^\s*//.*\r?\n', '' -replace '(?m)^[ ]+', '').Replace('@@VERSION@@', $progVer)
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

        # ---- web page texts: src\web\web_lang\<code>.ini -> the TXT object and the language list of the page
        # (en.ini is the base: it fixes the key order, and missing keys of other languages fall back to it)
        $wlDir = Join-Path $d 'web\web_lang'
        if (-not (Test-Path -LiteralPath (Join-Path $wlDir 'en.ini'))) { throw "Missing web language file: $wlDir\en.ini (English is the base language)" }
        $WebLangs = @{}
        foreach ($f in @(Get-ChildItem -LiteralPath $wlDir -Filter '*.ini' | Sort-Object Name)) {
            $code = $f.BaseName.ToLower()
            if ($code -notmatch '^[a-z]{2,8}(-[a-z0-9]{2,8})?$') { throw "Bad web language file name '$($f.Name)' (use a language code such as en.ini, tr.ini, de.ini)" }
            $o = New-Object System.Collections.Specialized.OrderedDictionary
            $n = 0
            foreach ($line in [IO.File]::ReadAllLines($f.FullName, [Text.Encoding]::UTF8)) {
                $n++
                $l = $line.Trim()
                if ($l.Length -eq 0 -or $l.StartsWith(';') -or $l.StartsWith('#')) { continue }
                $i = $l.IndexOf('=')
                if ($i -lt 1) { throw "web_lang\$($f.Name) line ${n}: expected 'key = value'" }
                $key = $l.Substring(0, $i).Trim()
                $val = $l.Substring($i + 1).Trim()
                if ($key -notmatch '^[A-Za-z0-9_]+$') { throw "web_lang\$($f.Name) line ${n}: bad key '$key' (letters, digits and _ only)" }
                if ($val.Length -ge 2 -and $val.StartsWith('"') -and $val.EndsWith('"')) { $val = $val.Substring(1, $val.Length - 2) }
                if ($o.Contains($key)) { throw "web_lang\$($f.Name) line ${n}: key '$key' appears twice" }
                $o[$key] = $val
            }
            if (-not $o.Contains('lang_name')) { throw "web_lang\$($f.Name): missing 'lang_name = ...' (the name shown in the language list)" }
            $WebLangs[$code] = $o
        }
        function JsStr($s) {
            $b = New-Object Text.StringBuilder
            [void]$b.Append("'")
            foreach ($ch in $s.ToCharArray()) {
                if ($ch -eq '\') { [void]$b.Append('\\') }
                elseif ($ch -eq "'") { [void]$b.Append("\'") }
                elseif ([int]$ch -gt 126 -or [int]$ch -lt 32) { [void]$b.Append(('\u{0:x4}' -f [int]$ch)) }
                else { [void]$b.Append($ch) }
            }
            [void]$b.Append("'")
            return $b.ToString()
        }
        $wlBase = $WebLangs['en']
        $wlOrder = @('en') + @($WebLangs.Keys | Where-Object { $_ -ne 'en' } | Sort-Object)
        $wlText = New-Object Text.StringBuilder
        $wlOpts = New-Object Text.StringBuilder
        Write-Host '  web languages:'
        foreach ($code in $wlOrder) {
            $o = $WebLangs[$code]
            $missing = @($wlBase.Keys | Where-Object { $_ -ne 'lang_name' -and -not $o.Contains($_) })
            $extra = @($o.Keys | Where-Object { -not $wlBase.Contains($_) })
            $msg = '    {0,-6} {1,3} texts' -f $code, ($o.Count - 1)
            if ($missing.Count -gt 0) { $msg += "   missing $($missing.Count) (English is used): " + (($missing | Select-Object -First 5) -join ', ') + $(if ($missing.Count -gt 5) { ' ...' }) }
            if ($extra.Count -gt 0) { $msg += "   unknown keys ignored by the page: " + (($extra | Select-Object -First 5) -join ', ') }
            Write-Host $msg
            $items = New-Object Collections.ArrayList
            foreach ($k in $wlBase.Keys) {
                if ($k -eq 'lang_name') { continue }
                $v = $(if ($o.Contains($k)) { $o[$k] } else { $wlBase[$k] })
                if ($k -eq 'strength') {
                    $parts = @($v.Split('|') | ForEach-Object { $_.Trim() })
                    if ($parts.Count -ne 5) { throw "web_lang\$code.ini: 'strength' needs exactly five words separated by |" }
                    [void]$items.Add("      $k`: [" + (($parts | ForEach-Object { JsStr $_ }) -join ', ') + ']')
                } else {
                    [void]$items.Add("      $k`: " + (JsStr $v))
                }
            }
            [void]$wlText.Append("    $code`: {`n" + ($items -join ",`n") + "`n    }")
            if ($code -ne $wlOrder[-1]) { [void]$wlText.Append(",`n") }
            $label = New-Object Text.StringBuilder
            foreach ($ch in $o['lang_name'].ToCharArray()) {
                if ([int]$ch -gt 126) { [void]$label.Append(('&#{0};' -f [int]$ch)) }
                elseif ($ch -eq '<') { [void]$label.Append('&lt;') }
                elseif ($ch -eq '&') { [void]$label.Append('&amp;') }
                else { [void]$label.Append($ch) }
            }
            [void]$wlOpts.Append("<option value=`"$code`">" + $label.ToString() + '</option>')
        }
        $tpl = $tpl.Replace('@@WEBLANG@@', $wlText.ToString()).Replace('@@LANGOPTS@@', $wlOpts.ToString())

        # ---- the SHA-256 rounds of the browser version, written out (all 64, constant indexes and constants): about 1.5x
        # faster in JavaScript than a loop. The rotation of the eight variables is done by renaming them from round to round.
        function Emit-Sha256Blocks {
            $K = ('428a2f98 71374491 b5c0fbcf e9b5dba5 3956c25b 59f111f1 923f82a4 ab1c5ed5 d807aa98 12835b01 243185be 550c7dc3 72be5d74 80deb1fe 9bdc06a7 c19bf174 ' +
                  'e49b69c1 efbe4786 0fc19dc6 240ca1cc 2de92c6f 4a7484aa 5cb0a9dc 76f988da 983e5152 a831c66d b00327c8 bf597fc7 c6e00bf3 d5a79147 06ca6351 14292967 ' +
                  '27b70a85 2e1b2138 4d2c6dfc 53380d13 650a7354 766a0abb 81c2c92e 92722c85 a2bfe8a1 a81a664b c24b8b70 c76c51a3 d192e819 d6990624 f40e3585 106aa070 ' +
                  '19a4c116 1e376c08 2748774c 34b0bcb5 391c0cb3 4ed8aa4a 5b9cca4f 682e6ff3 748f82ee 78a5636f 84c87814 8cc70208 90befffa a4506ceb bef9a3f7 c67178f2').Split(' ')
            if ($K.Count -ne 64) { throw 'SHA-256 constants: expected 64 values' }
            $n = 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'hh'
            $sb = New-Object Text.StringBuilder
            $nl = "`n"
            [void]$sb.Append('    var h0 = h[0], h1 = h[1], h2 = h[2], h3 = h[3], h4 = h[4], h5 = h[5], h6 = h[6], h7 = h[7], i, x, y, t, a, b, c, d, e, f, g, hh;' + $nl)
            [void]$sb.Append('    while (o < end) {' + $nl)
            [void]$sb.Append('      for (i = 0; i < 16; i++, o += 4) w[i] = (p[o] << 24) | (p[o + 1] << 16) | (p[o + 2] << 8) | p[o + 3];' + $nl)
            for ($i = 16; $i -lt 64; $i++) {
                [void]$sb.Append(('      x = w[{0}]; y = w[{1}]; w[{2}] = (w[{3}] + (((x >>> 7) | (x << 25)) ^ ((x >>> 18) | (x << 14)) ^ (x >>> 3)) + w[{4}] + (((y >>> 17) | (y << 15)) ^ ((y >>> 19) | (y << 13)) ^ (y >>> 10))) | 0;' -f ($i - 15), ($i - 2), $i, ($i - 16), ($i - 7)) + $nl)
            }
            [void]$sb.Append('      a = h0; b = h1; c = h2; d = h3; e = h4; f = h5; g = h6; hh = h7;' + $nl)
            for ($r = 0; $r -lt 64; $r++) {
                $q = $r % 8
                $A = $n[(8 - $q) % 8]; $B = $n[(9 - $q) % 8]; $C = $n[(10 - $q) % 8]; $D = $n[(11 - $q) % 8]
                $E = $n[(12 - $q) % 8]; $F = $n[(13 - $q) % 8]; $G = $n[(14 - $q) % 8]; $H = $n[(15 - $q) % 8]
                $s1 = "(((${E} >>> 6) | (${E} << 26)) ^ ((${E} >>> 11) | (${E} << 21)) ^ ((${E} >>> 25) | (${E} << 7)))"
                $s0 = "(((${A} >>> 2) | (${A} << 30)) ^ ((${A} >>> 13) | (${A} << 19)) ^ ((${A} >>> 22) | (${A} << 10)))"
                $ch = "(${G} ^ (${E} & (${F} ^ ${G})))"
                $mj = "((${A} & ${B}) | (${C} & (${A} | ${B})))"
                [void]$sb.Append("      t = (${H} + $s1 + $ch + 0x$($K[$r]) + w[$r]) | 0; ${D} = (${D} + t) | 0; ${H} = (t + $s0 + $mj) | 0;" + $nl)
            }
            [void]$sb.Append('      h0 = (h0 + a) | 0; h1 = (h1 + b) | 0; h2 = (h2 + c) | 0; h3 = (h3 + d) | 0; h4 = (h4 + e) | 0; h5 = (h5 + f) | 0; h6 = (h6 + g) | 0; h7 = (h7 + hh) | 0;' + $nl)
            [void]$sb.Append('    }' + $nl)
            [void]$sb.Append('    h[0] = h0; h[1] = h1; h[2] = h2; h[3] = h3; h[4] = h4; h[5] = h5; h[6] = h6; h[7] = h7;')
            return $sb.ToString()
        }
        $tpl = $tpl.Replace('@@SHA256_BLOCKS@@', (Emit-Sha256Blocks))

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
