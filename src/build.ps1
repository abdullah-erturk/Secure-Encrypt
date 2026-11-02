# Builds SecureEncrypt.cmd from the parts in this folder and computes its integrity signature.
#
#   SecureEncrypt.cmd is a GENERATED file. To change the code, edit the parts in src\ and run this script:
#       launcher.bat  integrity check + starts the PowerShell program
#       engine.ps1    menus, prompts, install / uninstall
#       lib.cs        crypto and archive core (also embedded in every *_decrypt.cmd)
#       dec.ps1       the decryptor that is embedded in every *_decrypt.cmd
#       stub.bat      batch start-up part of every *_decrypt.cmd
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
    $dec      = ReadSrc 'dec.ps1'
    $stub     = ReadSrc 'stub.bat'
    $shim     = ReadSrc 'shim.js.txt'

    Write-Host '[2/4] Assembling'
    function Here($name, $text) { "`$$name = @'`n" + $text.TrimEnd() + "`n'@`n" }
    $embed  = (Here 'LibSrc' $lib) + "`n" + (Here 'DecSrc' $dec) + "`n" + (Here 'StubSrc' $stub) + "`n" + (Here 'ShimSrc' $shim)
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
