# Değişiklik Günlüğü / Changelog

[🇹🇷 Türkçe](#türkçe) | [🇬🇧 English](#english)

---

## Türkçe

### v6.0 (v5'e göre değişenler)

v6, v5'in baştan yazılmış hâlidir. Eski betikler `old_v5\` klasöründe durur.

**Güvenlik**
* **Anahtar türetme güçlendirildi:** PBKDF2 (SHA-1, 10.000 yineleme) → **PBKDF2-HMAC-SHA256, 600.000 yineleme** (yineleme sayısı dosyada saklanır).
* **Bütünlük doğrulaması eklendi:** v5'te yalnızca AES-CBC vardı; v6 **AES-256-CBC + HMAC-SHA256 (Encrypt-then-MAC)** kullanır. Değiştirilmiş/bozuk dosya hiçbir şey yazılmadan reddedilir, yanlış parola tüm dosya çözülmeden anlaşılır.
* **Parola artık komut satırında geçmez:** v5, parolayı PowerShell komutunun içine yazıyordu (`$password='...'`); v6 parolayı `SecureString` olarak okur. `& ! % " '` gibi özel karakterli parolalar sorunsuz çalışır.
* **Orijinal SHA256 özeti** artık `_decrypt.cmd` içinde düz yazılı değil, şifreli verinin içinde saklanır.
* **Anahtar dosyası (keyfile)** desteği eklendi (parola yerine ya da parolayla birlikte, iki faktör). Yol yazılabilir, sürüklenebilir ya da `?` yazılarak "Dosya seç" penceresinden seçilebilir.
* **Parola doğrulama (iki kez sorulur) ve parola gücü göstergesi** eklendi.
* **Güvenli çıkarma:** arşiv içindeki yollar denetlenir (`..` ile klasör dışına yazma engellenir).
* **Çözücüde 3 deneme hakkı.**
* **Sertleştirmeler:** dosyadan okunan yineleme sayısı en fazla 10.000.000 olabilir; şifreleme/çözme sonrası parola ve anahtar baytları bellekte sıfırlanır; sağ tık yardımcısı yolları komut satırı yerine liste dosyasıyla aktarır (adında `%DEĞİŞKEN%` kalıbı olan dosyalar da çalışır). Ayrıntılar için `SECURITY_REVIEW.md`.
* **Orijinalleri silme seçeneği:** çıktı önce çözülüp karşılaştırılarak doğrulanır, sonra onayınızla silinir; kilitli dosyalarda işlem durmaz, silinemeyenler listelenir.
* **Parolasız mod:** v5'te yalnızca metin dosyaları XOR ile gizleniyordu; v6'da parolasız modda tüm veri sıkıştırılır ve XOR ile gizlenir (bu bir güvenlik sağlamaz, yalnızca düz metin görünmesini engeller).

**Kullanım**
* **Çoklu seçim:** v5'te aynı anda tek dosya veya klasör işlenebiliyordu; v6'da birden fazla dosya/klasör tek `_decrypt.cmd` içinde toplanır.
* **Klasör desteği yenilendi:** v5, klasörler için ZIP (Shell.Application / VBS) kullanıyordu; v6 kendi kapsayıcı biçimini kullanır. Bu yüzden Windows 7'de de Windows 11'deki gibi çalışır. Boş klasörler, değişiklik tarihi ve öznitelikler korunur.
* **Sağ tık menüsü yenilendi:** "Dosyayı Şifrele" ve "Klasörü Şifrele" ayrı girdileri yerine tek, nötr bir *Şifrele* girdisi; `*_decrypt.cmd` için *Şifreyi Çöz* girdisi eklendi. Çoklu seçimde Explorer'ın her öğe için pencere açması yerine **tek pencerede** işlenir.
* **Daha az soru:** çıktı klasörü sorulmaz (şifrelerken kaynağın yanına, çözerken `_decrypt.cmd`'nin yanına). Gelişmiş seçenekler (anahtar dosyası, orijinalleri silme) tek bir `[e/H]` sorusunun arkasındadır. Evet/hayır sorularında geçersiz giriş yeniden sorulur; çakışma ve menü soruları liste biçimindedir.
* **Çakışma yönetimi:** hedefte aynı ad varsa üzerine yaz / yeniden adlandır / atla / iptal.
* **Otomatik GZip sıkıştırma** (zaten sıkıştırılmış türler hariç).
* **Tek betik, çift dil:** v5'te ayrı `SecureEncrypt_TR.cmd` ve `SecureEncrypt_EN.cmd` vardı; v6'da tek `SecureEncrypt.cmd` Windows diline göre Türkçe veya İngilizce açılır (`set SE_LANG=tr|en` ile zorlanabilir).
* **Daha hızlı açılış:** v5 her adım için ayrı bir PowerShell başlatıyordu; v6 tek bir PowerShell programı çalıştırır.

**Uyumluluk ve altyapı**
* **Windows 7 SP1 / PowerShell 2.0 ve .NET 2.0** ile uyumlu olacak şekilde yazıldı ve Windows 7, 10, 11 üzerinde denendi.
* **Unicode desteği:** dosya/klasör adları ve parola her dilde olabilir; betik tamamen ASCII olduğundan sistem dili/kod sayfası fark etmez. `%TEMP%` yolu sistem kod sayfasında olmayan karakterler içerse bile çalışır.
* **3. parti uygulama gerekmez:** AES-256, PBKDF2, HMAC ve GZip tamamen Windows'un yerleşik bileşenleriyle (cmd, PowerShell, .NET Framework) yapılır.
* **Geliştirme düzeni:** kod `src\` içinde parçalara ayrıldı; `SecureEncrypt.cmd`, `src\build.ps1` ile üretilir ve SHA256 imzası otomatik hesaplanır (v5'te imza elle güncelleniyordu ve betik özetini panoya kopyalıyordu). `src\drag-drop_build.ps1.bat` ile sürükle-bırak derleme yapılabilir.

**Uyumluluk notu**
* v6 dosya biçimi (`SEv2`) v5'inkiyle uyumlu değildir. v5 ile oluşturulmuş `_decrypt.cmd` dosyaları kendi çözücülerini içerdiği için çalışmaya devam etmesi beklenir; yeni şifrelemeler v6 biçiminde yapılır.
* Sağ tıkta Windows, klasik menü komutları için **15'ten fazla öğe seçildiğinde** menüyü göstermez; bu Windows sınırıdır. Daha fazla öğe için dosyaları `SecureEncrypt.cmd` üzerine sürükleyip bırakın.

---

## English

### v6.0 (changes compared to v5)

v6 is a rewrite of v5. The old scripts are kept in `old_v5\`.

**Security**
* **Stronger key derivation:** PBKDF2 (SHA-1, 10,000 iterations) → **PBKDF2-HMAC-SHA256, 600,000 iterations** (the count is stored in the file).
* **Integrity check added:** v5 had plain AES-CBC only; v6 uses **AES-256-CBC + HMAC-SHA256 (encrypt-then-MAC)**. A modified or corrupted file is rejected before anything is written, and a wrong password is detected without decrypting the whole file.
* **The password no longer appears on a command line:** v5 put the password inside the PowerShell command (`$password='...'`); v6 reads it as a `SecureString`. Passwords with special characters such as `& ! % " '` work.
* **The original SHA256** is no longer written in clear text in `_decrypt.cmd`; it is stored inside the encrypted data.
* **Key file (keyfile)** support (instead of, or together with, a password; two-factor). The path can be typed, dragged in, or picked with a "Select file" dialog by typing `?`.
* **Password confirmation (asked twice) and a strength meter.**
* **Safe extraction:** archive paths are validated (no `..` escapes out of the target folder).
* **3 attempts in the decoder.**
* **Hardening:** the iteration count read from a file is limited to 10,000,000; password and key bytes are wiped from memory after encrypting/decrypting; the right-click helper passes the paths in a list file instead of the command line (file names containing a `%VARIABLE%` pattern work too). See `SECURITY_REVIEW.md`.
* **Delete-originals option:** the output is first verified by decrypting and comparing, then deleted after your confirmation; locked files do not stop the run, files that could not be deleted are listed.
* **No-password mode:** v5 only XOR-obfuscated text files; v6 compresses and XOR-obfuscates all data in this mode (not security, it only keeps the content from being readable as plain text).

**Usability**
* **Multiple items:** v5 handled one file or folder at a time; v6 bundles several files/folders into one `_decrypt.cmd`.
* **New folder handling:** v5 used ZIP (Shell.Application / VBS) for folders; v6 uses its own container format, so Windows 7 behaves like Windows 11. Empty folders, timestamps and attributes are preserved.
* **New right-click menu:** one neutral *Encrypt* entry instead of separate "Encrypt File" / "Encrypt Folder" entries, plus a *Decrypt* entry for `*_decrypt.cmd` files. A multi-selection is handled in **one window** instead of one window per item.
* **Fewer questions:** no output-folder question (encrypting writes next to the source, decrypting extracts next to the `_decrypt.cmd`). Advanced options (key file, delete originals) sit behind a single `[y/N]` question. Invalid yes/no input is asked again; conflict and menu questions are shown as lists.
* **Conflict handling:** overwrite all / rename / skip all / cancel.
* **Automatic GZip compression** (except for already-compressed types).
* **One script, two languages:** v5 had separate `SecureEncrypt_TR.cmd` and `SecureEncrypt_EN.cmd`; v6 is a single `SecureEncrypt.cmd` that opens in Turkish or English by Windows language (force with `set SE_LANG=tr|en`).
* **Faster start-up:** v5 started a separate PowerShell for every step; v6 runs one PowerShell program.

**Compatibility and internals**
* Written for **Windows 7 SP1 / PowerShell 2.0 and .NET 2.0**, and tested on Windows 7, 10 and 11.
* **Unicode support:** file/folder names and the password can be in any language; the script is pure ASCII, so the system language / code page does not matter. It also works when the `%TEMP%` path contains characters outside the system code page.
* **No third-party software needed:** AES-256, PBKDF2, HMAC and GZip are done entirely with Windows' built-in components (cmd, PowerShell, .NET Framework).
* **Development layout:** the code is split into parts in `src\`; `SecureEncrypt.cmd` is generated by `src\build.ps1`, which computes the SHA256 signature automatically (v5 required updating it by hand and copied the script hash to the clipboard). `src\drag-drop_build.ps1.bat` allows a drag-and-drop build.

**Compatibility notes**
* The v6 file format (`SEv2`) is not compatible with v5's. `_decrypt.cmd` files created with v5 carry their own decryptor, so they are expected to keep working; new encryptions use the v6 format.
* Windows does not show classic context-menu commands when **more than 15 items** are selected; this is a Windows limit. For more items, drag and drop them onto `SecureEncrypt.cmd`.
