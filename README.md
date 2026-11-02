<a href="https://buymeacoffee.com/abdullaherturk" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>
  
# SecureEncrypt v6
**SecureEncrypt (AES-256 Encrypt & Decrypt)**

![Platform](https://img.shields.io/badge/Platform-Windows_7_--_11-0078D6?style=for-the-badge)
![Tech](https://img.shields.io/badge/Tech-Batch_&_PowerShell-blue?style=for-the-badge)
![Security](https://img.shields.io/badge/Security-AES--256_|_HMAC--SHA256_|_PBKDF2-red?style=for-the-badge)

[![made-for-windows](https://img.shields.io/badge/Made%20for-Windows-00A4E3.svg?style=flat&logo=microsoft)](https://www.microsoft.com/)
[![Open Source?](https://img.shields.io/badge/Open%20source%3F-Of%20course%21%20%E2%9D%A4-009e0a.svg?style=flat)](https://github.com/abdullah-erturk/Secure-Encode)

![sample](https://github.com/abdullah-erturk/Secure-Encode/blob/main/preview.gif)

Dosya ve klasörleri isteğe bağlı **AES-256 parola / anahtar dosyası koruması** ile kendi kendini açabilen tek bir `.cmd` arşivine dönüştüren bir Windows betiği.

A Windows script that converts **files and folders** into a single, self-extracting `.cmd` archive, with optional **AES-256 password / key file protection**.

---

<details>
<summary><strong>Türkçe Tanıtım</strong></summary>

---

## Proje Hakkında

Bir veya birden fazla dosyayı/klasörü alıp, onları kendi kendini çözebilen (self-extracting) tek bir Windows komut dosyasına (`*_decrypt.cmd`) dönüştürür. Bu dosyayı Windows 7, 8.1, 10, 11 veya Server üzerinde çalıştırdığınızda (parola/anahtar dosyası varsa onları sorar) içeriği güvenle geri çıkarır. Harici yazılım gerekmez.

**3. parti uygulama gerekmez:** AES-256 şifreleme, PBKDF2, HMAC ve GZip tamamen **Windows'un yerleşik bileşenleriyle** yapılır: `cmd`, Windows PowerShell ve .NET Framework'ün kendi `System.Security.Cryptography` / `System.IO.Compression` sınıfları (yardımcı kod, Windows ile gelen C# derleyicisiyle çalışma anında derlenir). 7-Zip, OpenSSL, GPG gibi bir şey kurmanız, indirmeniz veya internete bağlanmanız gerekmez; şifreleme algoritmasının kendisi de elle yazılmamıştır, Windows'un standart kriptografi kütüphanesi kullanılır.

## ✨ Özellikler

**Şifreleme ve güvenlik**
* **Yerleşik Windows şifrelemesi:** AES-256, PBKDF2 ve HMAC-SHA256 için .NET Framework'ün kriptografi sınıfları kullanılır; 3. parti araç veya kütüphane yoktur.
* **AES-256-CBC + HMAC-SHA256 (Encrypt-then-MAC):** Dosya değiştirilmiş veya bozulmuşsa çözme **hiçbir şey yazmadan** reddedilir.
* **PBKDF2-HMAC-SHA256, 600.000 yineleme** ile anahtar türetme (yineleme sayısı dosyanın içinde saklanır). Rastgele 16 bayt salt ve IV.
* **Parola doğrulama (iki kez sorulur) ve parola gücü göstergesi.** Zayıf parolada uyarı verilir.
* **Anahtar dosyası (keyfile) desteği:** Parola yerine, ya da parolayla birlikte herhangi bir dosya anahtar olarak kullanılabilir (iki faktör). Anahtar dosyası sorulduğunda yolu yazabilir, dosyayı pencereye sürükleyebilir ya da **`?` yazıp "Dosya seç" penceresinden** seçebilirsiniz (sürükle-bırak çalışmayan yönetici pencerelerinde ve Server işletim sistemlerinde işe yarar; Server Core'da pencere açılamazsa yolu yazın). Bu özellik denenmiş ve çalıştığı görülmüştür.
* **Parola komut satırında geçmez**; `SecureString` olarak okunur, ara tamponlar kullanıldıktan sonra sıfırlanır. Özel karakterli (`& ! % " '`) parolalar sorunsuz çalışır.
* **Orijinal SHA256 özeti şifreli verinin içinde saklanır** (artık `_decrypt.cmd` içinde düz yazılı değildir).
* **Çözücüde 3 deneme hakkı;** yanlış parola anında (tüm dosyayı çözmeden) anlaşılır.
* **Güvenli çıkarma:** Arşiv içindeki yollar denetlenir (`..` ile klasör dışına yazma engellenir).
* **Betik Bütünlük Koruması:** `SecureEncrypt.cmd` çalışmadan önce kendi SHA256 imzasını kontrol eder (değişiklik tespiti içindir, saldırgana karşı koruma değildir).
* **Gelişmiş Sistem Dizin Koruması:** `C:\Windows`, `C:\Program Files`, `$Recycle.Bin`, `System Volume Information` vb. şifrelenemez. Yalnızca kullanıcı profiliniz ve sistem diski dışındaki diskler güvenlidir.

**Kullanım kolaylığı**
* **Çoklu dosya/klasör:** Aynı anda birden fazlasını sürükleyip bırakın ya da sağ tıkla seçin; hepsi tek `_decrypt.cmd` içinde toplanır.
* **Sağ tık menüsü:** Dosya, klasör ve karışık seçimler için tek bir *Şifrele* girdisi, `*_decrypt.cmd` dosyaları için *Şifreyi Çöz*. Çoklu seçimde Explorer her öğe için ayrı işlem başlatır; küçük bir yardımcı (`C:\Windows\SecureEncrypt.js`, pencere açmaz) Explorer'a o penceredeki **seçimin tamamını** sorar ve hepsini **tek bir pencerede** işler (süreye bağlı değildir, tek dosyada da bekleme olmaz). Seçim alınamazsa (örneğin masaüstü) kuyruk yöntemi kullanılır: geç gelenler siz parolayı yazarken ana pencereye eklenir ("Seçilen N öğe daha eklendi"), çok geç kalanlar ayrı pencerede açılır, hiçbir öğe kaybolmaz. Windows Script Host kapalıysa yerleşik kuyruk yöntemi kullanılır.
* **Klasör sorulmaz:** şifrelerken `_decrypt.cmd` kaynağın yanına yazılır, çözerken içerik `_decrypt.cmd` dosyasının bulunduğu klasöre çıkar.
* **Orijinalleri silme seçeneği:** Önce çıktı çözülüp karşılaştırılarak **doğrulanır**, sonra onayınızla silinir; isterseniz üzerine yazılarak (SSD'lerde garanti vermez).
* **Çakışma yönetimi:** Hedefte aynı ad varsa üzerine yaz / yeniden adlandır / atla / iptal.
* **Orijinal değişiklik tarihi ve öznitelikler korunur**; boş klasörler de şifrelenir.
* **Otomatik GZip sıkıştırma** (zaten sıkıştırılmış türler hariç).
* **Tek betik, çift dil:** Windows dili Türkçe ise Türkçe, değilse İngilizce açılır. Zorlamak için `set SE_LANG=tr` veya `en`.
* **Unicode desteği:** Dosya ve klasör adları ile parola her dilde olabilir (Çince, Japonca, Korece, Arapça, Kiril, Türkçe vb.); adlar ve parola Unicode olarak işlenir, çözerken aynen geri gelir. Betik dosyası tamamen ASCII olduğundan Windows'un sistem dil / kod sayfası ayarı fark etmez. Kullanıcı adı veya `%TEMP%` yolunda sistemin kod sayfasında olmayan karakterler olsa bile çalışır (derleme gerekirse geçici olarak ASCII bir klasöre alınır). Not: Konsol yazı tipi bazı karakterleri ekranda `?` veya kutu olarak gösterebilir, bu yalnızca görüntüdür, işlemi etkilemez. Soruları cevaplarken (`e/h`, `y/n`) klavye düzeni Latin olmalıdır. Bu destek, farklı kod sayfaları (`chcp`) ve Unicode adlarla denenmiştir; gerçek Çince/Japonca/Korece/Arapça Windows kurulumunda denenmemiştir.
* **Akış tabanlı işleme:** Çok büyük dosyalar bellek hatası vermeden işlenir; ilerleme çubuğu gösterilir.
* **Kendi kendini çözen:** Veri ve çözme mantığı tek `.cmd` dosyasındadır (salt okunur oluşturulur).
* **Klasörler için ZIP/Shell.Application gerekmez;** kendi kapsayıcı biçimi kullanılır, bu yüzden Windows 7'de de aynı şekilde çalışır.

**Parolasız mod:** Parola ve anahtar dosyası girilmezse veri **şifrelenmez**; yalnızca sıkıştırılır ve XOR ile gizlenir (düz metin olarak görünmez ama bu güvenlik sağlamaz).

## 🚀 Nasıl Kullanılır?

### Kurulum (isteğe bağlı)
1. `SecureEncrypt.cmd` dosyasını indirip **çift tıklayın**, UAC'ye "Evet" seçin.
2. Kurulum sorusuna **E** seçin. Sağ tık menüsüne *Şifrele* (dosya ve klasör) ve `*_decrypt.cmd` için *Şifreyi Çöz* eklenir.
3. Güncellemek veya kaldırmak için betiği yeniden çalıştırın (1 = güncelle, 2 = kaldır).

### Şifreleme
* **Sağ tık** ile (kurulum gerekir) ya da bir veya daha fazla dosya/klasörü `SecureEncrypt.cmd` üzerine **sürükleyip bırakarak** (kurulum gerekmez).
* Varsayılan akış kısadır: **Parola** (Enter = atla) → **Parola doğrulama** → **Gelişmiş seçenekler? [e/H]**. Enter ile geçerseniz şifreleme hemen başlar, çıktı kaynağın yanına yazılır ve orijinaller kalır. **E** derseniz sırayla **Anahtar dosyası** ve **Orijinaller** (N / D / S) sorulur. D veya S seçerseniz çıktı doğrulandıktan sonra orijinaller ek onay istenmeden silinir.
* Çıktı: `Ad_decrypt.cmd` (birden fazla öğede `Ad_and_N_more_decrypt.cmd`).

### Çözme
`..._decrypt.cmd` dosyasını çift tıklayın (veya sağ tık → *Şifreyi Çöz*). Gerekirse parola ve/veya anahtar dosyası sorulur; içerik, dosyanın bulunduğu klasöre çıkarılır. Sonunda SHA256 doğrulaması gösterilir.

## 🔒 Güvenlik Modeli: Şifrem Kırılabilir mi?

Güvenlik, seçtiğiniz parolanın (ve/veya anahtar dosyasının) gücüne **bağlıdır**.

* **Algoritma (AES-256): Kırılamaz.** Saldırgan algoritmayı değil, *parolanızı tahmin etmeyi* dener.
* **PBKDF2 (600.000 yineleme)** her tahmini yavaşlatır, ama zayıf parolayı kurtarmaz.

| Şifre Gücü | Örnek Şifre | Güvenlik Durumu |
| :--- | :--- | :--- |
| Çok Zayıf | `1`, `123`, `password123` | **GÜVENSİZ** |
| Güçlü | `Benim!Sifrem-1990` | **GÜVENLİ** |
| Paranoyak | `kirmizi-araba-77-hizli-gider?` veya parola + anahtar dosyası | **ÇOK GÜÇLÜ** |

**Sınırlar (bilmeniz gerekenler):**
* Parolasız modda veri şifrelenmez.
* "Betik Bütünlük Koruması" yalnızca kazara/basit değişiklikleri yakalar; betiği değiştirebilen biri bu denetimi de değiştirebilir.
* Dosya adları ve boyutlar `_decrypt.cmd` içinde şifreli tutulur, ancak toplam dosya boyutu tahmin edilebilir.
* Silme (özellikle üzerine yazma) SSD ve bulut eşitlemeli klasörlerde kalıntı bırakmayacağını garanti edemez.
* Parolayı unutursanız veriyi kurtarmanın yolu yoktur.

## ⚙️ Bağımlılıklar

* Windows 7 SP1, 8.1, 10, 11 veya Server
* Windows PowerShell 2.0 veya üzeri (Windows 7 ve sonrasında hazır gelir) ve .NET Framework 2.0+ (Windows 7'de hazır gelir; ayrıca .NET 4.5 **gerekmez**)
* Yardımcı kod ilk çalıştırmada `Add-Type` ile derlenir (bir iki saniye sürer).

> Not: Yardımcı kod C# 2.0 dilinde ve .NET 2.0 API'leriyle yazılmıştır ve bu kısıtla derlendiği doğrulanmıştır. Windows 7 (PowerShell 2.0) ve Windows 10/11 (PowerShell 5.1) üzerinde uçtan uca denenmiş, sorunsuz çalıştığı görülmüştür.

## 📝 Teknik Detaylar

### Dosya biçimi (`*_decrypt.cmd`)
`[batch başlatıcı][#PS_BEGIN … PowerShell + C# çözücü … #PS_END][ikili veri]`

İkili veri (`SEv2`):
* **Mod 2 (AES):** `"SEv2" | 2 | bayraklar | yineleme(4) | salt(16) | IV(16) | anahtar-kontrol(16) | AES-CBC(SHA256(32) + [GZip](kapsayıcı)) | HMAC-SHA256(32)`
* **Mod 1 (parolasız):** `"SEv2" | 1 | bayraklar | SHA256(32) | XOR([GZip](kapsayıcı))`
* Anahtar türetme: `master = PBKDF2-HMAC-SHA256(parola‖SHA256(anahtar dosyası), salt, yineleme)`; `şifreleme anahtarı = HMAC(master,"SE2-ENC")`, `MAC anahtarı = HMAC(master,"SE2-MAC")`, anahtar-kontrol = `HMAC(MAC anahtarı,"SE2-KEYCHECK")[0..16]`.
* Kapsayıcı (`SEC1`): öğe sayısı, toplam boyut, her öğe için yol (UTF-8), değişiklik tarihi, öznitelikler, uzunluk ve veri.

### Kaynak kodu ve geliştirme
* **Kullanmak için yalnızca `SecureEncrypt.cmd` yeterlidir.** Tek başına çalışır; `src\` ve `old_v5\` klasörlerine ihtiyaç yoktur. Başka bir bilgisayara yalnızca bu dosyayı taşımanız yeterli.
* **Kodda değişiklik yapmak için `src\` klasöründeki parçaları düzenleyin.** `SecureEncrypt.cmd` bu parçalardan **üretilen** bir dosyadır; doğrudan düzenlemek zordur (Türkçe karakterler `\u011f` gibi kodlanır, C# yorumları ve girintiler atılır) ve bir sonraki derlemede değişiklikleriniz kaybolur.

| Parça | Görevi |
| :--- | :--- |
| `launcher.bat` | Bütünlük denetimi ve PowerShell programını başlatır |
| `engine.ps1` | Menüler, sorular, kurulum / kaldırma |
| `lib.cs` | Şifreleme ve arşiv çekirdeği (her `_decrypt.cmd` içine de gömülür) |
| `dec.ps1` | Her `_decrypt.cmd` içine gömülen çözücü |
| `stub.bat` | `_decrypt.cmd` dosyasının batch başlangıç kısmı |
| `shim.js.txt` | Sağ tık yardımcısı, JScript kaynağı (çoklu seçim → tek pencere) |

**Değişiklik adımları:** 1) `src\` içindeki ilgili dosyayı düzenleyin, 2) `powershell -File src\build.ps1` çalıştırın (`SecureEncrypt.cmd` yeniden üretilir ve SHA256 imzası otomatik hesaplanır), 3) kurulu sağ tık kopyasını güncellemek için `SecureEncrypt.cmd` dosyasını çalıştırıp **1 (Güncelle)** seçin. Eski `_decrypt.cmd` dosyaları kendi çözücülerini içinde taşıdığı için güncellenmez; yeniden şifrelemeniz gerekir.

**Kolay derleme (sürükle-bırak):** `src\build.ps1` dosyasını komut yazmadan derlemek için `src\drag-drop_build.ps1.bat` dosyasının üzerine sürükleyip bırakın (ya da bat dosyasına çift tıklayın, o zaman `src\build.ps1` derlenir). Yardımcı PowerShell'i `-ExecutionPolicy Bypass` ile başlatır, yönetici izni gerekmez. Bu yardımcı yalnızca geliştirme içindir; kullanım için gerekmez.

Eski v5 betikleri `old_v5\` klasöründedir.

## 🔄 v5 → v6: Neler Değişti? (ayrıntılar için [CHANGELOG.md](CHANGELOG.md) dosyasına bakınız)

v6, v5'in baştan yazılmış hâlidir.

| Konu | v5 | v6 |
| :--- | :--- | :--- |
| Anahtar türetme | PBKDF2 (SHA-1), 10.000 yineleme | **PBKDF2-HMAC-SHA256, 600.000 yineleme** |
| Bütünlük | Yok (yalnızca AES-CBC) | **HMAC-SHA256** (değişen/bozuk dosya yazmadan reddedilir) |
| Parola | PowerShell komutunun içine yazılıyordu | `SecureString`, komut satırında geçmez; özel karakterler çalışır |
| Orijinal SHA256 | `_decrypt.cmd` içinde düz yazı | Şifreli verinin içinde |
| Anahtar dosyası, parola gücü, 3 deneme | Yok | **Var** |
| Seçim | Tek dosya veya klasör | **Çoklu dosya/klasör**, tek `_decrypt.cmd` |
| Klasörler | ZIP (Shell.Application / VBS) | Kendi kapsayıcı biçimi (Win7'de de aynı) |
| Sağ tık | "Dosyayı / Klasörü Şifrele" ayrı girdileri | Tek nötr *Şifrele* + *Şifreyi Çöz*; çoklu seçimde **tek pencere** |
| Sorular | Çok adımlı | Çıktı klasörü sorulmaz; gelişmiş seçenekler tek `[e/H]` sorusunda |
| Orijinalleri silme | Yok | Çözüp karşılaştırarak doğrular, sonra siler |
| Sıkıştırma | Yok | Otomatik GZip |
| Dil | Ayrı TR ve EN betikleri | **Tek betik**, Windows diline göre otomatik |
| Unicode | – | Dosya adı/parola her dilde, kod sayfasından bağımsız |
| 3. parti uygulama | Gerekmez | Gerekmez (yerleşik Windows bileşenleri) |
| Windows 7 | – | PowerShell 2.0 / .NET 2.0 uyumlu, denenmiştir |
| İmza | Elle güncellenir, özet panoya kopyalanırdı | `src\build.ps1` ile otomatik hesaplanır |

**Uyumluluk:** v6 dosya biçimi v5'inkiyle uyumlu değildir. v5 ile oluşturulmuş `_decrypt.cmd` dosyaları kendi çözücülerini içerdiği için çalışmaya devam etmesi beklenir.

**Bilinen sınır:** Windows, klasik sağ tık komutlarını **15'ten fazla öğe** seçildiğinde göstermez. Daha fazlası için dosyaları `SecureEncrypt.cmd` üzerine sürükleyip bırakın.

</details>

---

<details>
<summary><strong>English Description</strong></summary>

---

## About the Project

Takes one or more files/folders and converts them into a single **self-extracting** Windows command script (`*_decrypt.cmd`). Running it on Windows 7, 8.1, 10, 11 or Server asks for the password / key file (if used) and safely restores the content. No external software required.

**No third-party software needed:** AES-256 encryption, PBKDF2, HMAC and GZip are done entirely with **Windows' built-in components**: `cmd`, Windows PowerShell and the .NET Framework's own `System.Security.Cryptography` / `System.IO.Compression` classes (the helper code is compiled at run time by the C# compiler that ships with Windows). You do not have to install or download anything such as 7-Zip, OpenSSL or GPG, and no internet connection is used; the cipher itself is not hand-written either, it is Windows' standard cryptography library.

## ✨ Features

**Encryption & security**
* **Built-in Windows encryption:** AES-256, PBKDF2 and HMAC-SHA256 come from the .NET Framework cryptography classes; there is no third-party tool or library.
* **AES-256-CBC + HMAC-SHA256 (encrypt-then-MAC):** a modified or corrupted file is rejected **before anything is written**.
* **PBKDF2-HMAC-SHA256, 600,000 iterations** (the count is stored in the file). Random 16-byte salt and IV.
* **Password confirmation (asked twice) and a strength meter**, with a warning for weak passwords.
* **Key file support:** use any file as a key instead of, or together with, a password (two-factor). At the key file prompt you can type the path, drag the file into the window, or **type `?` to pick it in a "Select file" dialog** (useful in elevated windows where drag and drop does not work and on Server operating systems; on Server Core, where the dialog cannot open, type the path). This feature has been tested and works.
* **The password never appears on a command line;** it is read as a `SecureString` and intermediate buffers are zeroed after use. Passwords with special characters (`& ! % " '`) work.
* **The original SHA256 is stored inside the encrypted data** (it is no longer written in clear text in `_decrypt.cmd`).
* **3 attempts in the decoder;** a wrong password is detected immediately without decrypting the whole file.
* **Safe extraction:** archive paths are validated (no `..` escapes out of the target folder).
* **Script Integrity Protection:** `SecureEncrypt.cmd` verifies its own SHA256 signature before running (it detects accidental/simple changes; it does not protect against an attacker).
* **System Directory Protection:** `C:\Windows`, `C:\Program Files`, `$Recycle.Bin`, `System Volume Information`, etc. cannot be encrypted. Only your user profile and non-system drives are allowed.

**Convenience**
* **Multiple files/folders:** drag several at once or multi-select with right-click; they are bundled into one `_decrypt.cmd`.
* **Right-click menu:** one *Encrypt* entry for files, folders and mixed selections, and *Decrypt* for `*_decrypt.cmd` files. With a multi-selection Explorer starts one process per item; a small helper (`C:\Windows\SecureEncrypt.js`, opens no window) asks Explorer for the **whole selection** of that window and handles everything in **one window** (no timing involved, no delay for a single file). If the selection cannot be read (e.g. on the desktop) a queue method is used: late instances are added to the main window while you type the password ("Added N more selected item(s)"), anything even later gets its own window, so no item is ever lost. If Windows Script Host is disabled, the built-in queue method is used instead.
* **No folder questions:** when encrypting, the `_decrypt.cmd` is written next to the source; when decrypting, the content is extracted next to the `_decrypt.cmd` file.
* **Delete-originals option:** the output is first **verified by decrypting and comparing**, then deleted after your confirmation; optionally overwritten first (no guarantee on SSDs).
* **Conflict handling:** overwrite all / rename / skip all / cancel.
* **Timestamps and attributes are preserved;** empty folders can be encrypted too.
* **Automatic GZip compression** (except for already-compressed types).
* **One script, two languages:** Turkish when Windows is Turkish, English otherwise. Force with `set SE_LANG=tr` or `en`.
* **Unicode support:** file and folder names and the password can be in any language (Chinese, Japanese, Korean, Arabic, Cyrillic, Turkish, etc.); names and password are handled as Unicode and come back unchanged when decrypting. The script file is pure ASCII, so the system language / code page of Windows does not matter. It also works when the user name or `%TEMP%` path contains characters outside the system code page (the compile step is moved to an ASCII folder temporarily if needed). Note: the console font may show some characters as `?` or boxes; that is display only and does not affect the operation. Keep the keyboard layout on Latin when answering prompts (`e/h`, `y/n`). This was tested with different code pages (`chcp`) and Unicode names; it has not been tested on a real Chinese/Japanese/Korean/Arabic Windows installation.
* **Streaming:** very large files are handled without memory errors, with a progress bar.
* **Self-extracting:** data and logic live in one `.cmd` (created read-only).
* **No ZIP/Shell.Application needed for folders;** an own container format is used, so Windows 7 behaves exactly like Windows 11.

**No-password mode:** if you enter neither a password nor a key file, the data is **not encrypted**; it is only compressed and XOR-obfuscated (not readable as plain text, but not security).

## 🚀 How to Use?

### Installation (optional)
1. Download `SecureEncrypt.cmd` and **double-click** it; accept the UAC prompt.
2. Answer **Y** to the install question. *Encrypt* (files and folders) and *Decrypt* (for `*_decrypt.cmd`) are added to the right-click menu.
3. Run the script again to update or uninstall (1 = update, 2 = uninstall).

### Encrypting
* **Right-click** (needs installation) or **drag & drop** one or more files/folders onto `SecureEncrypt.cmd` (no installation needed).
* The default flow is short: **Password** (ENTER = skip) → **Confirm password** → **Advanced options? [y/N]**. Press ENTER and encryption starts right away, the output is written next to the source and the originals are kept. Answer **Y** to also be asked for **Key file** and **Originals** (N / D / S). With D or S the originals are deleted without a further prompt once the output has been verified.
* Output: `Name_decrypt.cmd` (`Name_and_N_more_decrypt.cmd` for several items).

### Decrypting
Double-click the `..._decrypt.cmd` file (or right-click → *Decrypt*). You are asked for the password and/or key file if needed; the content is extracted into the folder the file is in. A SHA256 check is shown at the end.

## 🔒 Security Model: Can My Password Be Broken?

Security depends **on the strength of your password (and/or key file)**.

* **The algorithm (AES-256): unbreakable.** An attacker tries to *guess your password*, not to break AES.
* **PBKDF2 (600,000 iterations)** slows down every guess, but cannot save a weak password.

| Password Strength | Example | Security Status |
| :--- | :--- | :--- |
| Very Weak | `1`, `123`, `password123` | **INSECURE** |
| Strong | `My!Pass-1990` | **SECURE** |
| Paranoid | `red-car-77-fast-goes?` or password + key file | **VERY STRONG** |

**Limits (please read):**
* In no-password mode nothing is encrypted.
* "Script Integrity Protection" only catches accidental or naive changes; someone who can edit the script can edit the check too.
* File names and sizes are kept inside the encrypted data, but the total size of the archive is visible.
* Deleting (even overwriting) cannot promise to leave no remnants on SSDs or cloud-synced folders.
* If you forget the password there is no way to recover the data.

## ⚙️ Dependencies

* Windows 7 SP1, 8.1, 10, 11 or Server
* Windows PowerShell 2.0 or later (built in from Windows 7) and .NET Framework 2.0+ (built in on Windows 7; .NET 4.5 is **not** required)
* The helper code is compiled with `Add-Type` on first use (takes a second or two).

> Note: the helper code is written in C# 2.0 against .NET 2.0 APIs and was verified to compile under that restriction. It was tested end-to-end on Windows 7 (PowerShell 2.0) and Windows 10/11 (PowerShell 5.1) and works without problems.

## 📝 Technical Details

### File format (`*_decrypt.cmd`)
`[batch launcher][#PS_BEGIN … PowerShell + C# decoder … #PS_END][binary payload]`

Binary payload (`SEv2`):
* **Mode 2 (AES):** `"SEv2" | 2 | flags | iterations(4) | salt(16) | IV(16) | key-check(16) | AES-CBC(SHA256(32) + [GZip](container)) | HMAC-SHA256(32)`
* **Mode 1 (no password):** `"SEv2" | 1 | flags | SHA256(32) | XOR([GZip](container))`
* Key derivation: `master = PBKDF2-HMAC-SHA256(password‖SHA256(key file), salt, iterations)`; `enc key = HMAC(master,"SE2-ENC")`, `MAC key = HMAC(master,"SE2-MAC")`, key-check = `HMAC(MAC key,"SE2-KEYCHECK")[0..16]`.
* Container (`SEC1`): entry count, total size, then per entry: path (UTF-8), modified time, attributes, length and data.

### Source code and development
* **`SecureEncrypt.cmd` alone is enough to use the program.** It is self-contained; the `src\` and `old_v5\` folders are not needed. Copy only this file to another computer.
* **To change the code, edit the parts in `src\`.** `SecureEncrypt.cmd` is a **generated** file; editing it directly is awkward (Turkish characters are stored as `\u011f` escapes, C# comments and indentation are stripped) and your changes are lost on the next build.

| Part | Purpose |
| :--- | :--- |
| `launcher.bat` | Integrity check, starts the PowerShell program |
| `engine.ps1` | Menus, prompts, install / uninstall |
| `lib.cs` | Crypto and archive core (also embedded in every `_decrypt.cmd`) |
| `dec.ps1` | The decryptor embedded in every `_decrypt.cmd` |
| `stub.bat` | Batch start-up part of a `_decrypt.cmd` |
| `shim.js.txt` | Right-click helper, JScript source (multi-selection → one window) |

**To make a change:** 1) edit the relevant file in `src\`, 2) run `powershell -File src\build.ps1` (regenerates `SecureEncrypt.cmd` and computes its SHA256 signature automatically), 3) to update the installed right-click copy, run `SecureEncrypt.cmd` and choose **1 (Update)**. Existing `_decrypt.cmd` files carry their own decryptor and are not updated; re-encrypt to get the new behaviour.

**Easy build (drag and drop):** to build without typing a command, drag `src\build.ps1` onto `src\drag-drop_build.ps1.bat` (or double-click the bat file, which then builds `src\build.ps1`). The helper starts PowerShell with `-ExecutionPolicy Bypass` and needs no administrator rights. The helper is for development only; it is not needed to use the program.

The old v5 scripts are in `old_v5\`.

## 🔄 v5 → v6: What Changed? (see the [CHANGELOG.md](CHANGELOG.md) file for details)

v6 is a rewrite of v5.

| Topic | v5 | v6 |
| :--- | :--- | :--- |
| Key derivation | PBKDF2 (SHA-1), 10,000 iterations | **PBKDF2-HMAC-SHA256, 600,000 iterations** |
| Integrity | None (plain AES-CBC) | **HMAC-SHA256** (modified/corrupted file rejected before writing) |
| Password | Written inside the PowerShell command | `SecureString`, never on a command line; special characters work |
| Original SHA256 | Clear text in `_decrypt.cmd` | Inside the encrypted data |
| Key file, strength meter, 3 attempts | No | **Yes** |
| Selection | One file or folder | **Multiple files/folders** in one `_decrypt.cmd` |
| Folders | ZIP (Shell.Application / VBS) | Own container format (same on Win7) |
| Right-click | Separate "Encrypt File / Folder" entries | One neutral *Encrypt* + *Decrypt*; multi-selection in **one window** |
| Questions | Many steps | No output-folder question; advanced options behind one `[y/N]` question |
| Delete originals | No | Verifies by decrypting and comparing, then deletes |
| Compression | No | Automatic GZip |
| Language | Separate TR and EN scripts | **One script**, automatic by Windows language |
| Unicode | – | Names/password in any language, independent of the code page |
| Third-party software | Not needed | Not needed (built-in Windows components) |
| Windows 7 | – | PowerShell 2.0 / .NET 2.0 compatible, tested |
| Signature | Updated by hand, hash copied to the clipboard | Computed automatically by `src\build.ps1` |

**Compatibility:** the v6 file format is not compatible with v5's. `_decrypt.cmd` files created with v5 carry their own decryptor, so they are expected to keep working.

**Known limit:** Windows does not show classic right-click commands when **more than 15 items** are selected. For more, drag and drop them onto `SecureEncrypt.cmd`.

</details>

<div align="center">

Made with ❤️ by [Abdullah ERTÜRK](https://github.com/abdullah-erturk)

[🌐 erturk-dev.netlify.app](https://erturk-dev.netlify.app)  
  
</div>
