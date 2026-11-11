# Değişiklik Günlüğü / Changelog

[🇹🇷 Türkçe](#türkçe) | [🇬🇧 English](#english)

---

## Türkçe

### v8.1 (v8.0'a göre değişenler)

Hata düzeltme sürümüdür; yeni özellik yoktur, dosya biçimi (`SEv2`) değişmedi.

* **Eski şifreli dosya artık erken silinmez:** Aynı adda bir `_decrypt.cmd` varken yeniden şifreleme yapılırsa eski dosya işlem başında siliniyordu; şifreleme yarıda kesilir ya da hata verirse elde hiçbir kopya kalmıyordu. Artık eski dosya, yenisi eksiksiz yazıldıktan sonra değiştirilir.
* **"Orijinalleri sil" yalnızca arşivlenenleri siler:** Silme artık şifreli kopyaya gerçekten giren dosyalarla sınırlıdır. Okunduktan sonra klasöre eklenen ya da değişen (boyutu veya değişiklik tarihi farklı) dosyalar silinmez ve sarı bir uyarıyla listelenir; klasörler yalnızca boşaldıysa kaldırılır. Önceden klasör tümüyle siliniyordu, bu yüzden şifreli kopyada bulunmayan dosyalar da kaybolabiliyordu.
* **Adında `&` olan dosyaları sürükleyip bırakma:** Explorer, bırakılan yolda boşluk yoksa tırnak koymaz; adında `&` bulunan bir dosya ya da klasör `SecureEncrypt.cmd` üzerine bırakıldığında ad bölünüyor, `&` işaretinden sonraki bölüm komut olarak çalıştırılabiliyordu. Bırakılan yollar artık komut satırının kendisinden okunur ve betik, kalan bölüm çalışmadan kapanır. Üretilen `_decrypt.cmd` dosyalarının başlatıcısı bu sürümde değişmedi.
* **Windows 11 yeni sağ tık menüsünde "Şifreyi çöz":** Menü yardımcı programı `_decrypt.cmd` dosyasını artık sistemdeki `cmd.exe` ile başlatır. Geçerli olması için kurulumun yeniden yapılması gerekir (Kaldır, sonra Kur).
* **Tarayıcı sürümü, büyük dosyada donma:** Büyük bir dosyayla (4,39 GB ile görüldü) işlem başladıktan sonraki ilk saniyelerde sayfa yanıt vermiyor, ilerleme çubuğu güncellenmiyor ve düğmelere tıklanamıyordu. İşlem artık düzenli aralıklarla tarayıcıya sıra verir; ilerleme baştan itibaren görünür ve iptal düğmesi çalışır.
* **Tarayıcı sürümü, çözme için dosya seçimi:** Masaüstü tarayıcılarda dosya penceresi yalnızca `.cmd` dosyalarını listeler ("Tüm dosyalar" yine seçilebilir). Telefon ve tabletlerde süzgeç uygulanmaz.
* **Dil dosyaları:** Silinmeyen dosyalar uyarısı için `del_kept` anahtarı dokuz dile eklendi.

### v8.0 (v7.0'a göre değişenler)

* **Tarayıcı sürümünde büyük dosya modu:** Dosya Sistemi Erişimi API'sini destekleyen tarayıcılarda (Chrome, Edge, Opera, Samsung Internet) 1,5 GB sınırı kalktı. Veri parça parça (4 MiB) işlenir ve doğrudan diske yazılır; bellek sınır olmaz. Şifrelerken kaydedilecek dosya, çözerken hedef klasör sorulur. İlerleme çubuğu ve **iptal düğmesi** vardır; parolalı işlem iki adımdır (okuma/denetim, sonra şifreleme/çözme). Üretilen dosya normal `SEv2` dosyasıdır. 2,6 GB ve 5,65 GB ile (masaüstü) ve 2,33 GB ile (Android, Chrome ve Samsung Internet; klasör dahil) denenmiştir. Firefox ve Safari'de bu özellik yoktur, 1,5 GB sınırı sürer.
* **Büyük dosyada parola isteğe bağlı:** Parola ve anahtar dosyası olmadan içerik Windows sürümündeki gibi yalnızca gizlenir (mod 1, güvenlik sağlamaz); sonuçta sarı uyarı gösterilir. Parolasız dosyalar Windows ile iki yönlü uyumludur.
* **Büyük dosya çözme:** Dosyalar yeni bir alt klasör açılmadan doğrudan seçilen klasöre (arşivdeki alt klasörleriyle) yazılır; var olan dosyanın üzerine yazılmaz, yeni dosyanın adına " (2)" gibi numara eklenir; iptal ya da hata olursa bu işlemin oluşturduğu dosyalar silinir. Disk kökü seçilince boş "şu klasöre yazıldı" satırı artık gösterilmez.
* **Tarayıcıda SHA-256/HMAC hızlandı:** 64 tur tek tek açık yazılmış kodla yaklaşık 1,6 kat (~105 → ~165 MB/sn). Kod `srcbuild.ps1` tarafından üretilir.
* **Windows'ta AES hızlandı:** `RijndaelManaged` yerine hızlı sağlayıcı (`AesCryptoServiceProvider`, `SymmetricAlgorithm.Create("AES")`); bulunamazsa eskisine döner. 600 MB: şifreleme 15,3 → 6,3 sn, çözme 14,6 → 4,8 sn. Çıktı biçimi aynıdır.
* **Renkli sonuç mesajları:** Sonuç penceresinde DİKKAT (uyarı) satırları sarı, hata satırları kırmızı gösterilir (dilden bağımsız).
* **Web dil dosyaları ayrıldı:** Tarayıcı sürümünün metinleri `src\web\web_lang*.ini` dosyalarına taşındı (tr, en, de, es, fr, it, nl, ru, uk); derleme sırasında hepsi sayfaya gömülür, eksik anahtarlar İngilizceye döner ve derleme uyarı verir.
* **Sürüm numarası:** "Hakkında" penceresinin başlığında artık sürüm görünür ("SecureEncrypt v8.0 - Hakkında"). Numara yalnızca `srcengine.ps1` içindeki `$Version` değerinden alınır; `build.ps1` pencere koduna işler.
* **Uyumluluk:** Dosya biçimi (`SEv2`) değişmedi. v6/v7 ile oluşturulmuş `_decrypt.cmd` dosyaları v8'de (Windows ve tarayıcı) açılır, v8'in dosyaları eski çözücülerle de açılır (iki yönlü denendi). Daha önce üretilmiş `_decrypt.cmd` dosyaları kendi çözücülerini içerdiğinden eskisi gibi çalışır ama yeni hız artışlarından yararlanmaz. Windows 7 / PowerShell 2.0'da hem Windows uygulaması hem tarayıcı sürümü (hızlı AES sağlayıcı ile) denenmiş ve sorunsuz çalışmıştır; hızlı AES sağlayıcı yoksa eskisine dönülür.

### v7.0 (v6.0'a göre değişenler)

* **Pencere arayüzü:** Şifreleme, çözme ve kurulum için arkası bulanık (buzlu cam) modern bir pencere; Windows 7'den 11'e çalışır (DPI ve küçük ekranlara uyum). Pencere açılamazsa konsol arayüzü kullanılır (`/console` veya `set SE_GUI=0` ile konsol zorlanabilir). Pencere artık varsayılandır; kurulum penceresinde "Kurmadan kullan" düğmesi, modern klasör seçici ve "Hakkında" düğmesi bulunur.
* **Dil dosyaları ve dil seçimi:** Metinler `src\lang\*.ini` dosyalarına taşındı; yeni dil için `en.ini` kopyalanıp çevrilir ve `build.ps1` çalıştırılır, tüm dil dosyaları otomatik gömülür. Pencerede sağ üstten dil değiştirilebilir (seçim kaydedilir).
* **Windows 11 yeni sağ tık menüsü:** Kurulum (Windows 11 22H2+) yeni menü girdisini de ekler, Kaldır geri alır; yönetici izniyle imzasız bir deneme paketi kaydedilir. Ayrıntılar için README'ye bakın. Menü yardımcı programı (`SecureEncryptShell.exe`) sürüm bilgisi, simge ve manifest ile derlenir (tamamen açık kaynak, kaynak: `src\ext\shell_server.cs`); imzasız olduğu için bazı antivirüs makine öğrenmesi motorları yanlış pozitif verebilir.
* **Gizli komut penceresi:** Pencere modunda komut penceresi (Windows 11'de Windows Terminal) açılışta kısa bir an görünüp hemen kapanır; PowerShell gizli ve ayrı çalışır. Pencere açılamazsa metin modu görünür bir konsolda sürer.
* **Tarayıcı sürümü (`web\index.html`):** Linux, macOS, Android ve iOS'ta şifreleme ve çözme; tek dosyalık statik sayfa, her şey tarayıcıda yapılır. Windows biçimiyle uyumludur. Çevrimiçi: https://erturk-dev.netlify.app/secureencrypt; `web\index.html` dosyasına çift tıklayarak çevrimdışı da kullanılabilir. Ayrıntılar için README'ye bakın.
* Windows 7 / PowerShell 2.0 düzeltmeleri, uygulama simgesi (başlık çubuğu ve görev çubuğu), 3 yanlış parola sonrası uyarı.
* **Yeni pencere düzeni:** Şifreleme ve çözme pencereleri tarayıcı sürümü gibi iki sütunlu ve yataydır; "Şifrele / Şifreyi çöz" sekmeleri tek pencerededir. Çözme sekmesinde `_decrypt.cmd` seçilir ya da bırakılır (tek bir `_decrypt.cmd`, `SecureEncrypt.cmd` üzerine bırakılırsa bu sekme açılır). Pencere taşındıktan sonra cam arka planın yenilenmesi artık yumuşak geçişle yapılır.
* **Tarayıcı sürümü:** Şifreleme ve çözme sonunda geçen süre gösterilir. Şifre çözme sekmesinde yaklaşık 1,5 GB'tan büyük bir `_decrypt.cmd` seçilirse nedeni açıklanır (Windows'ta SecureEncrypt ile çözülmesi önerilir); şifreleme tarafındaki uyarı da aynı yönlendirmeyi içerir.
* **4 GB üzeri `_decrypt.cmd`:** Başlatıcının çıkışı düzeltildi (artık şifreli veriyi komut sanıp bozuk satırlar yazmaz). Windows bu boyuttaki `.cmd` dosyasını çift tıklamayla açamaz; şifreleme sonunda uyarı gösterilir, çözmek için sağ tık "Şifreyi çöz" kullanılır.

### v6.0 (v5'e göre değişenler)

v6, v5'in baştan yazılmış hâlidir. Eski betikler `old_versions\` klasöründe durur.

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
* **Tek betik, çok dil:** v5'te ayrı `SecureEncrypt_TR.cmd` ve `SecureEncrypt_EN.cmd` vardı; v6'da tek `SecureEncrypt.cmd` Windows diline göre açılır (`set SE_LANG=tr|en|...` ile zorlanabilir).
* **Daha hızlı açılış:** v5 her adım için ayrı bir PowerShell başlatıyordu; v6 tek bir PowerShell programı çalıştırır.

**Uyumluluk ve altyapı**
* **Windows 7 SP1 / PowerShell 2.0 ve .NET 2.0** ile uyumlu olacak şekilde yazıldı ve Windows 7, 10, 11 üzerinde denendi.
* **Unicode desteği:** dosya/klasör adları ve parola her dilde olabilir; betik tamamen ASCII olduğundan sistem dili/kod sayfası fark etmez. `%TEMP%` yolu sistem kod sayfasında olmayan karakterler içerse bile çalışır.
* **3. parti uygulama gerekmez:** AES-256, PBKDF2, HMAC ve GZip tamamen Windows'un yerleşik bileşenleriyle (cmd, PowerShell, .NET Framework) yapılır.
* **Geliştirme düzeni:** kod `src\` içinde parçalara ayrıldı; `SecureEncrypt.cmd`, `src\build.ps1` ile üretilir ve SHA256 imzası otomatik hesaplanır (v5'te imza elle güncelleniyordu ve betik özetini panoya kopyalıyordu). `src\drag-drop_build.ps1.bat` ile sürükle-bırak derleme yapılabilir.

**Uyumluluk notu**
* v6 dosya biçimi (`SEv2`) v5'inkiyle uyumlu değildir (v7'de biçim değişmedi; v6 ve v7 dosyaları birbirinin çözücüsüyle açılır). v5 ile oluşturulmuş `_decrypt.cmd` dosyaları kendi çözücülerini içerdiği için çalışmaya devam etmesi beklenir; yeni şifrelemeler v6 biçiminde yapılır.
* Sağ tıkta Windows, klasik menü komutları için **15'ten fazla öğe seçildiğinde** menüyü göstermez; bu Windows sınırıdır. Daha fazla öğe için dosyaları `SecureEncrypt.cmd` üzerine sürükleyip bırakın.

---

## English

### v8.1 (changes compared to v8.0)

A bug-fix release; no new features, and the file format (`SEv2`) did not change.

* **The old encrypted file is no longer deleted early:** when a `_decrypt.cmd` of the same name already existed, encrypting again deleted the old file at the start; if the run was interrupted or failed, no copy was left. The old file is now replaced only after the new one has been written completely.
* **"Delete originals" removes only what was archived:** deleting is now limited to the files that really went into the encrypted copy. Files added to a folder or changed after they were read (different size or modification time) are kept and listed with an amber warning; folders are removed only when they end up empty. Previously the whole folder was deleted, so files missing from the encrypted copy could be lost too.
* **Dragging and dropping files with `&` in the name:** Explorer does not quote a dropped path that has no spaces; when a file or folder with `&` in its name was dropped onto `SecureEncrypt.cmd`, the name was split and the part after the `&` could be run as a command. Dropped paths are now read from the command line itself and the script closes before the remaining part can run. The launcher of the generated `_decrypt.cmd` files did not change in this release.
* **"Decrypt" in the new Windows 11 context menu:** the menu helper now starts the `_decrypt.cmd` file with the system's `cmd.exe`. The installation has to be repeated for this to take effect (Uninstall, then Install).
* **Browser version, freeze with large files:** with a large file (seen with 4.39 GB) the page did not respond during the first seconds after the start; the progress bar did not update and the buttons could not be clicked. The work now hands control back to the browser at regular intervals; progress is visible from the start and the Cancel button works.
* **Browser version, choosing the file to decrypt:** on desktop browsers the file dialog lists `.cmd` files only ("All files" can still be chosen). No filter is applied on phones and tablets.
* **Language files:** the `del_kept` key for the kept-files warning was added to all nine languages.

### v8.0 (changes compared to v7.0)

* **Large file mode in the browser version:** in browsers that support the File System Access API (Chrome, Edge, Opera, Samsung Internet) the 1.5 GB limit is gone. Data is processed piece by piece (4 MiB) and written straight to disk, so memory is not a limit. You choose the file to save when encrypting and the target folder when decrypting. There is a progress bar and a **Cancel button**; work with a password takes two steps (reading/checking, then encrypting/decrypting). The result is an ordinary `SEv2` file. Tested with 2.6 GB and 5.65 GB (desktop) and 2.33 GB (Android, Chrome and Samsung Internet; folders included). Firefox and Safari do not have this feature, so the 1.5 GB limit applies there.
* **Password optional for large files:** without a password and key file the content is only hidden, as in the Windows version (mode 1, no security); an amber warning is shown in the result. No-password files are compatible with Windows in both directions.
* **Large file decrypting:** files are written straight into the chosen folder (with the archive's sub folders) without creating a new sub folder; an existing file is never overwritten, a number such as " (2)" is added to the new file's name; on a cancel or an error the files this run created are removed. The empty "written to the folder" line is no longer shown when a drive root is chosen.
* **Faster SHA-256/HMAC in the browser:** about 1.6x (~105 → ~165 MB/s) with all 64 rounds written out. The code is generated by `srcbuild.ps1`.
* **Faster AES on Windows:** the fast provider (`AesCryptoServiceProvider`, via `SymmetricAlgorithm.Create("AES")`) replaces `RijndaelManaged`; it falls back to the old one if missing. 600 MB: encrypt 15.3 → 6.3 s, decrypt 14.6 → 4.8 s. The output format is the same.
* **Coloured result messages:** in the result window WARNING lines are amber and error lines red (independent of the language).
* **Web language files split out:** the texts of the browser version moved to `src\web\web_lang*.ini` (tr, en, de, es, fr, it, nl, ru, uk); the build embeds them all into the page, missing keys fall back to English and the build warns.
* **Version number:** the title of the "About" window now shows the version ("SecureEncrypt v8.0 - About"). The number comes only from `$Version` in `srcengine.ps1`; `build.ps1` passes it to the window code.
* **Compatibility:** the file format (`SEv2`) did not change. `_decrypt.cmd` files created with v6/v7 open in v8 (Windows and browser) and v8 files open with the older decryptors (tested in both directions). Previously created `_decrypt.cmd` files carry their own decryptor, so they keep working but do not get the new speed-ups. On Windows 7 / PowerShell 2.0 both the Windows app and the browser version were tested (with the fast AES provider) and work without problems; the old AES provider is used if the fast one is missing.

### v7.0 (changes compared to v6.0)

* **Window interface:** a modern frosted-glass (blurred background) window for encrypting, decrypting and setup; works on Windows 7 to 11 (adapts to DPI and small screens). The console interface is used when no window can be shown (force it with `/console` or `set SE_GUI=0`). The window is now the default; the setup window has a "Use without installing" button, a modern folder picker and an "About" button.
* **Language files and language selection:** the texts moved to `src\lang\*.ini`; to add a language copy `en.ini`, translate it and run `build.ps1`, all language files are embedded automatically. The language can be changed from the top right of the window (the choice is saved).
* **Windows 11 new context menu:** the installation (Windows 11 22H2+) also adds the new menu entry and Uninstall removes it; an unsigned test package is registered with administrator rights. See the README for details. The menu helper (`SecureEncryptShell.exe`) is built with version info, icon and manifest (fully open source, see `src\ext\shell_server.cs`); being unsigned, some antivirus machine-learning engines may report a false positive.
* **Hidden command window:** in window mode the command window (Windows Terminal on Windows 11) only flashes briefly and closes; PowerShell runs hidden and detached. If no window can be shown, the text mode continues in a visible console.
* **Browser version (`web\index.html`):** encrypt and decrypt on Linux, macOS, Android and iOS; a single static page, everything runs in the browser. Compatible with the Windows format. Online: https://erturk-dev.netlify.app/secureencrypt; it can also be used offline by double-clicking `web\index.html`. See the README for details.
* Windows 7 / PowerShell 2.0 fixes, application icon (title bar and taskbar), a warning after 3 wrong passwords.
* **New window layout:** the encrypt and decrypt windows are landscape with two columns like the browser version; "Encrypt / Decrypt" tabs share one window. On the decrypt tab a `_decrypt.cmd` is chosen or dropped (dropping a single `_decrypt.cmd` onto `SecureEncrypt.cmd` opens this tab). The frosted background is now refreshed with a soft fade after the window was moved.
* **Browser version:** the time taken by encryption and decryption is shown. On the Decrypt tab a `_decrypt.cmd` larger than about 1.5 GB now gets an explanation (decrypt it with SecureEncrypt on Windows); the encrypt-side warning points there as well.
* **`_decrypt.cmd` larger than 4 GB:** the launcher's exit was fixed (it no longer runs the encrypted data as commands and prints garbage lines). Windows cannot open a `.cmd` file of that size by double-click; a warning is shown when the encryption finishes, and "Decrypt" from the right-click menu is used to decrypt.

### v6.0 (changes compared to v5)

v6 is a rewrite of v5. The old scripts are kept in `old_versions\`.

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
* **One script, many languages:** v5 had separate `SecureEncrypt_TR.cmd` and `SecureEncrypt_EN.cmd`; v6 is a single `SecureEncrypt.cmd` that opens in the Windows language (force with `set SE_LANG=tr|en|...`).
* **Faster start-up:** v5 started a separate PowerShell for every step; v6 runs one PowerShell program.

**Compatibility and internals**
* Written for **Windows 7 SP1 / PowerShell 2.0 and .NET 2.0**, and tested on Windows 7, 10 and 11.
* **Unicode support:** file/folder names and the password can be in any language; the script is pure ASCII, so the system language / code page does not matter. It also works when the `%TEMP%` path contains characters outside the system code page.
* **No third-party software needed:** AES-256, PBKDF2, HMAC and GZip are done entirely with Windows' built-in components (cmd, PowerShell, .NET Framework).
* **Development layout:** the code is split into parts in `src\`; `SecureEncrypt.cmd` is generated by `src\build.ps1`, which computes the SHA256 signature automatically (v5 required updating it by hand and copied the script hash to the clipboard). `src\drag-drop_build.ps1.bat` allows a drag-and-drop build.

**Compatibility notes**
* The v6 file format (`SEv2`) is not compatible with v5's (the format did not change in v7; v6 and v7 files open with each other's decryptor). `_decrypt.cmd` files created with v5 carry their own decryptor, so they are expected to keep working; new encryptions use the v6 format.
* Windows does not show classic context-menu commands when **more than 15 items** are selected; this is a Windows limit. For more items, drag and drop them onto `SecureEncrypt.cmd`.
