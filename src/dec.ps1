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
    press      = 'Çıkış için herhangi bir tuşa basın...'
    compile    = 'Yardımcı kod derlenemedi (.NET Framework gerekli). Ayrıntılar:'
    format     = 'HATA: Desteklenmeyen veya bozuk dosya.'
    header     = '================== ŞİFRE ÇÖZME İŞLEMİ =================='
    file       = 'Dosya      : {0}'
    enc_aes    = 'Koruma     : AES-256 ile şifreli'
    enc_none   = 'Koruma     : yok (yalnızca sıkıştırılmış + gizlenmiş)'
    needs      = 'Gereken    : {0}'
    n_pw       = 'parola'
    n_kf       = 'anahtar dosyası'
    n_both     = 'parola + anahtar dosyası'
    t_pw       = 'Parola'
    t_kf       = 'Anahtar dosyası (yol yazın, dosyayı sürükleyin veya ? yazıp seçin)'
    kf_missing = 'Anahtar dosyası bulunamadı: {0}'
    kf_pick_title = 'Anahtar dosyasını seçin'
    kf_pick_fail  = 'Dosya seçme penceresi açılamadı (örneğin Server Core). Lütfen yolu yazın.'
    wrong      = 'Parola veya anahtar dosyası yanlış ({0}/{1}).'
    conflict   = 'Zaten var: {0}|  [O] Hepsinin üzerine yaz|  [R] Yeniden adlandır (ikisini de tut)|  [S] Hepsini atla|  [C] İptal|Seçiminiz [O/R/S/C]:'
    lbl_ver    = 'Doğrulanıyor'
    lbl_ext    = 'Çıkarılıyor '
    kdf        = 'Anahtar türetiliyor (PBKDF2): Parola ve anahtar dosyası doğrulanıyor.'
    mac_fail   = 'HATA: Bütünlük denetimi BAŞARISIZ. Dosya bozulmuş veya değiştirilmiş. Hiçbir şey çıkarılmadı.'
    cancelled  = 'İptal edildi.'
    err        = 'HATA: {0}'
    done       = 'Tamamlandı. {0} öğe şuraya çıkarıldı: {1}'
    sha        = 'Hesaplanan SHA256: {0}'
    sha_ok     = 'SHA256: BAŞARILI'
    sha_fail   = 'SHA256: BAŞARISIZ (veri orijinaliyle eşleşmiyor)'
    footer     = '================== ŞİFRE ÇÖZME İŞLEMİ =================='
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
