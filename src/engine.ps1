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
    press         = 'Çıkış için herhangi bir tuşa basın...'
    use_hint1     = 'Kurulum yapmadan da kullanabilirsiniz.'
    use_hint2     = 'Dosya veya klasörleri şifrelemek için bu betiğin üzerine sürükleyip bırakın (birden fazla olabilir).'
    need_admin    = 'Kurulum için Yönetici ayrıcalıkları gerekiyor. İzin isteniyor...'
    admin_denied  = 'Yönetici izni verilmedi.'
    installed     = 'SecureEncrypt sistemde zaten kurulu.'
    menu          = '  [1] Güncelle / yeniden kur|  [2] Kaldır|  [3] Çıkış'
    choice        = 'Seçiminiz [1/2/3] (numarayı yazıp ENTER''a basın)'
    not_installed = 'SecureEncrypt sistemde kurulu değil.'
    q_install     = 'Kurmak istiyor musunuz'
    installing    = 'Kuruluyor...'
    install_ok    = 'Kurulum başarıyla tamamlandı.'
    install_menu  = 'Sağ tık menüsü eklendi: dosya/klasörler için Şifrele, *_decrypt.cmd dosyaları için Şifreyi Çöz.'
    uninstalling  = 'Kaldırılıyor...'
    uninstall_ok  = 'Kaldırma işlemi başarıyla tamamlandı.'
    cancelled     = 'İptal edildi.'
    menu_encrypt  = 'Şifrele (Secure Encrypt AES-256)'
    menu_dec      = 'Şifreyi Çöz (Secure Encrypt)'
    warning       = '========================== UYARI =========================='
    forbidden     = 'Bu konum bir sistem klasörüdür. Güvenlik nedeniyle burada şifreleme yapılamaz.'
    notfound      = 'Yol bulunamadı: {0}'
    items         = 'İşlenecek öğeler ({0}):'
    more_items    = '  ... ve {0} öğe daha'
    t_pw          = 'Parola (atlamak için ENTER)'
    t_pw2         = 'Parolayı doğrulayın'
    pw_strength   = 'Parola gücü: {0}'
    strength0     = 'çok zayıf'
    strength1     = 'zayıf'
    strength2     = 'orta'
    strength3     = 'iyi'
    strength4     = 'güçlü'
    pw_mismatch   = 'Parolalar eşleşmiyor. Tekrar deneyin.'
    pw_weak       = 'Bu parola zayıf. Yine de kullanılsın mı?'
    q_adv         = 'Gelişmiş seçenekler (anahtar dosyası, orijinalleri silme)'
    t_kf          = 'Anahtar dosyası (yol yazın, dosyayı sürükleyin veya ? yazıp seçin; atlamak için ENTER)'
    kf_missing    = 'Anahtar dosyası bulunamadı: {0}'
    kf_pick_title = 'Anahtar dosyasını seçin'
    kf_pick_fail  = 'Dosya seçme penceresi açılamadı (örneğin Server Core). Lütfen yolu yazın.'
    late_added    = 'Seçilen {0} öğe daha eklendi - toplam {1}.'
    late_skipped  = 'Atlandı (sistem klasörü): {0}'
    kf_note       = 'NOT: Bu anahtar dosyasının içeriği değişirse veya dosya kaybolursa verinize bir daha ulaşılamaz. Yedeğini saklayın.'
    no_enc        = 'Parola veya anahtar dosyası yok: veri ŞİFRELENMEYECEK (yalnızca sıkıştırılır ve gizlenir).'
    enc_on        = 'Şifreleme: AES-256-CBC + HMAC-SHA256, anahtar PBKDF2-SHA256 ({0} yineleme) ile türetilir.'
    dont_forget   = 'ÖNEMLİ: BU PAROLAYI / ANAHTAR DOSYASINI UNUTMAYIN. Onsuz verinin geri getirilmesi mümkün değildir.'
    t_delete      = 'Şifrelemeden sonra orijinal öğelere ne yapılsın?|  [N] Kalsın (varsayılan)|  [D] Silinsin|  [S] Üzerine yazılıp silinsin'
    t_delete_ask  = 'Seçiminiz [N/D/S] (ENTER = N)'
    exists_q      = 'Çıktı dosyası zaten var: {0}  Üzerine yazılsın mı?'
    section       = '================== ŞİFRELEME İŞLEMİ =================='
    src_info      = 'Öğe sayısı: {0}    Toplam boyut: {1}'
    src_sha       = 'SHA256    : {0}'
    mode_label    = 'Mod       : {0}'
    mode1         = 'sıkıştırılmış + gizlenmiş (ŞİFRELİ DEĞİL)'
    mode2         = 'AES-256 ile şifreli'
    comp_on       = 'GZip ile sıkıştırıldı'
    comp_off      = 'sıkıştırılmadı (zaten sıkıştırılmış tür)'
    skipped       = 'Atlandı (erişilemiyor / bağlantı): {0}'
    out_info      = 'Çözücü dosya: {0}  ({1})'
    verified      = 'Doğrulama başarılı (çıktı çözülüp karşılaştırıldı).'
    changed       = 'İşlem sırasında bir kaynak dosya değişti. Lütfen tekrar deneyin.'
    empty         = 'Şifrelenecek bir şey yok.'
    err           = 'HATA: {0}'
    del_skip      = 'Orijinaller SİLİNMEDİ (çıktı bir kaynak klasörün içinde ya da bazı öğeler atlandı).'
    del_ok        = 'Orijinal öğe(ler) silindi.'
    del_fail      = 'Orijinallerin tamamı silinemedi: {0}'
    del_partial   = 'Bazı orijinaller SİLİNEMEDİ ({0}); geri kalanlar silindi:'
    del_partial_hint = 'Şifreli kopya eksiksiz oluşturuldu. Bu dosyaları kullanan programı kapatıp elle silebilirsiniz.'
    elapsed       = 'Süre: {0}'
    success       = 'BAŞARILI - Tüm işlemler tamamlandı.'
    lbl_hash      = 'Özet alınıyor'
    lbl_pack      = 'Paketleniyor '
    lbl_ver       = 'Doğrulanıyor '
    kdf           = 'Anahtar türetiliyor (PBKDF2)...'
    compile       = 'Yardımcı kod derlenemedi (.NET Framework gerekli). Ayrıntılar:'
    yn            = 'E/H'
    yes_chars     = 'e,evet,y'
    no_chars      = 'h,hayır,hayir,n'
    yn_invalid    = 'Lütfen {0} veya {1} yazın (varsayılan için ENTER).'
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

#@@EMBED@@

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
