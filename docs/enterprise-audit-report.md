# ENTPA Bayi Teknik Destek — Enterprise Denetim Raporu

**Denetim tarihi:** 3 Eylül 2026  
**İncelenen repository:** `tuncak207-hue/bayi-teknik-destek-yeni-v1`  
**İncelenen branch/commit:** `main` / `67a4ff0` (`Add files via upload`)  
**Kapsam:** Android uygulaması, NestJS backend, Next.js admin paneli, GitHub Actions, canlı Render endpointi, güvenlik, çalışabilirlik, performans ve görsel tutarlılık.  
**Kapsam dışı:** iOS geliştirme ve iOS release işlemleri.

## Yönetici özeti

Repository’nin backend ve admin tarafı şu an derlenebilir durumdadır. Backend unit testleri **5 test suite ve 22 test ile tamamen başarılı**, admin lint ve production build başarılı, backend production dependency audit sonucunda yüksek veya kritik açık bulunmamıştır. Canlı Render health endpointi HTTP 200 döndürmekte, korumalı doküman endpointi kimliksiz isteğe HTTP 401 vermekte ve temel güvenlik başlıkları etkin durumdadır.

Buna karşılık Android kalite kapısı şu an temiz değildir. Kullanıcı tarafından sağlanan `flutter analyze` çıktısında iki gerçek Dart analiz hatası bulunmuştur: `ai_assistant_screen.dart:163` ve `phone_login_screen.dart:160` satırlarında `invalid_constant`. GitHub’daki son Mobile CI koşusu da `Analyze` adımında tam olarak bu iki nedenle başarısız olmuştur. Bu nedenle mevcut Android release pipeline’ı enterprise kalite kriterlerini karşılamıyor.

En yüksek öncelikli yapılandırma riski, repository’nin güncel `main` branch’inde Android sürümünün **`0.1.0+30`** ve release workflow’unda `--build-number=30` olmasıdır. Önceki kullanıcı gereksinimi versionCode 27 idi; current repository ile önceki production artifact arasında tutarsızlık oluşmuştur. Play Console’a yüklemeden önce hedef sürüm kodu açıkça kararlaştırılmalı ve workflow, `pubspec.yaml` ile aynı kaynaktan sürüm üretmelidir.

İkinci kritik konu, repository dokümantasyonunun kaynak kodla güncel olmamasıdır. README, mobil platform klasörlerinin olmadığını ve pgvector alanının `vector(1536)` olduğunu söylüyor; güncel mobil yapılandırma ve önceki canlı geçiş bilgileri bununla çelişmektedir. Ayrıca workflow production endpointlerini hard-code ediyor ve Google servis yapılandırması repository’de izlenebilir durumda. Bu yapı çalışabilir olsa da enterprise seviyede environment/secret yönetimi ve release yönetişimi açısından iyileştirilmelidir.

## Doğrulanan başarılı kontroller

| Alan | Kontrol | Sonuç |
|---|---|---|
| Backend | `npm ci`, Prisma generate, `npm run build` | Başarılı |
| Backend test | Jest | 5 suite, 22 test, tamamı başarılı |
| Backend bağımlılıkları | `npm audit --omit=dev --audit-level=high` | 0 high, 0 critical |
| Admin | ESLint | Başarılı |
| Admin | Next.js production build | Başarılı; 22 route üretildi |
| Admin bağımlılıkları | `npm audit --omit=dev --audit-level=high` | 0 high, 0 critical |
| Canlı backend | `GET /api/v1/health` | HTTP 200 |
| Yetkisiz erişim | `GET /api/v1/documents` auth olmadan | HTTP 401 |
| HTTP güvenliği | Helmet, HSTS, CSP, X-Content-Type-Options, X-Frame-Options | Etkin |
| Mobile CI | Son GitHub run | Başarısız; Analyze adımında duruyor |
| Yerel sandbox | Flutter SDK | Kurulu değil; yerel Flutter analizi çalıştırılamadı |
| Kullanıcı Flutter çıktısı | `flutter analyze` | 2 gerçek hata, çok sayıda info/deprecation uyarısı |

## Önceliklendirilmiş bulgular

| ID | Önem | Bulgu | Etki | Önerilen aksiyon |
|---|---|---|---|---|
| A-01 | **Kritik** | Android `flutter analyze` iki `invalid_constant` hatasıyla başarısız | Android kalite kapısı ve CI başarısız; release öncesi güvenilirlik düşer | Runtime localization kullanılan `const` widget’lardan `const` kaldırılmalı; CI tekrar çalıştırılmalı |
| A-02 | **Kritik** | Repository’de version `0.1.0+30`, workflow’da `--build-number=30`; önceki gereksinim versionCode 27 | Play Console sürüm yönetimi ve kullanıcı beklentisiyle tutarsızlık | Sürüm numarasını tek kaynaktan yönetmek; 27 mi 30 mu kararı verilmeden release alınmamalı |
| A-03 | **Yüksek** | Voyage API ödeme yöntemi olmadan 3 RPM/10K TPM limiti uyguluyor | Dokümanların bir kısmı Hazır, bir kısmı Hata; batch işlemleri düzensiz | Billing durumunu izlemek, queue/rate limiter eklemek ve 429 için Retry-After’a uymak |
| A-04 | **Yüksek** | Production workflow API ve Socket URL’lerini dosya içinde sabitliyor | Ortam değişimi ve emergency rollback zorlaşır; yanlış backend’e build riski | GitHub Environment variable/secrets kullanıp HTTPS formatını doğrulayan tek bir config step’i oluşturmak |
| A-05 | **Yüksek** | README güncel kaynak kod ve deploy durumu ile çelişiyor | Kurulum, migration ve release işlemlerinde yanlış yönlendirme | README’yi güncel branch üzerinde yeniden yazmak; özellikle vector boyutu, Android klasörleri ve endpoint bilgilerini düzeltmek |
| A-06 | **Yüksek** | Admin production API varsayılanı `/api/v1`; `next.config.js` içinde rewrite yok | Admin ayrı domain’de deploy edilirse API istekleri yanlış hosta gidebilir; upload/login kırılabilir | Production’da `NEXT_PUBLIC_API_URL` zorunlu yapılmalı veya kontrollü Next rewrite eklenmeli |
| A-07 | **Orta** | `CORS_ORIGINS` production’da zorunlu ama varsayılan local origin yalnızca `http://localhost:3001` | Yanlış Render CORS ayarı admin upload ve cookie akışını bozar | Render’da admin production origin’ini açıkça tanımlamak; wildcard kullanmamak; smoke test eklemek |
| A-08 | **Orta** | `AI_API_KEY` ve `EMBEDDING_API_KEY` ayrımı operational olarak kolay karışıyor | Yanlış sağlayıcı key’i ile upload sonrası işleme başarısız olur | Environment names/health check ile provider ve model doğrulaması yapılmalı |
| A-09 | **Orta** | Admin refresh akışı HttpOnly cookie kullanıyor; backend refresh endpointi cookie yanında Bearer refresh token da kabul ediyor | Refresh token’ın iki taşıma kanalına açılması saldırı yüzeyini büyütür; cookie/CSRF tasarımı karmaşıklaşır | Admin refresh için cookie-only, mobil refresh için ayrı açık bir contract ve rotasyon/reuse detection uygulanmalı |
| A-10 | **Orta** | Flutter analizinde çok sayıda `prefer_const_constructors`, deprecated API ve async `BuildContext` uyarısı var | Teknik borç, gelecekteki Flutter sürümlerinde kırılma ve gereksiz rebuild riski | Önce gerçek hatalar; sonra warning budget ile const/deprecation/mounted düzeltmeleri |
| A-11 | **Orta** | Görsel denetim tam cihaz render’ı ile doğrulanamadı; sandbox’ta Flutter SDK yok | Android ekranlarının farklı cihaz boyutlarında gerçek taşma/kontrast davranışı kesinleşmedi | VS Code/gerçek Android cihazda ekran görüntüsü matrisi ve erişilebilirlik testi yapılmalı |
| A-12 | **Düşük** | GitHub Dependabot, Code Scanning ve Secret Scanning API kontrolleri yetki/özellik nedeniyle okunamadı | Repository’nin GitHub native güvenlik panoları bağımsız doğrulanamadı | Repository Settings’ten Dependabot alerts, secret scanning ve code scanning etkinleştirilmeli |

## Android kod ve release denetimi

### Gerçek analiz hataları

Kullanıcı tarafından sağlanan analiz çıktısında `AppLocalizations.of(context)` runtime değerleri `const` widget içinde kullanılmıştır. `ai_assistant_screen.dart:159-165` bölümündeki `const Padding` içinde `title` ve `description` runtime localization çağrılarıdır. Aynı hata `phone_login_screen.dart:159-163` içindeki `const InputDecoration` için geçerlidir. Bu alanlarda `const` kaldırılmalı veya localization değeri const olmayan bir widget ağacında kullanılmalıdır.

Bu iki hata yalnızca stil uyarısı değildir; GitHub Mobile CI’nin `Analyze` job’ını exit code 1 ile durdurmaktadır. Kullanıcı çıktısındaki diğer mesajlar çoğunlukla performans önerileri ve deprecated API uyarılarıdır; ancak `use_build_context_synchronously` gibi lifecycle uyarıları gerçek cihazda ekran kapatıldıktan sonra navigation/snackbar hatalarına dönüşebileceği için ayrıca temizlenmelidir.

### Sürüm ve production endpoint tutarlılığı

Güncel repository’de `mobile/pubspec.yaml` sürümü `0.1.0+30` olarak görünmektedir. `mobile-release.yml` workflow’u da signed AAB’yi `--build-number=30` ile üretmektedir. Bu, önceki production release hedefi olan versionCode 27 ile çelişir. Kullanıcı 27’yi korumak istiyorsa yeni commit’te `pubspec.yaml` ve workflow birlikte 27’ye alınmalı; Play Console’da daha önce 27’den yüksek bir build yüklenmişse aynı versionCode tekrar kullanılamayacağı unutulmamalıdır. Bu nedenle release işlemi öncesinde Play Console’daki son yüklenmiş versionCode kontrol edilmelidir.

Workflow production endpointlerini şu an doğrudan YAML içine yazıyor: `https://bayi-teknik-destek-yeni-v1-1.onrender.com/api/v1` ve `/chat`. Bu bağlantı mevcut canlı servisi doğru gösterse de enterprise release sürecinde URL’nin GitHub Environment değişkeninden gelmesi, HTTPS ve host allowlist doğrulamasından geçmesi ve artifact metadata’sına yazılması daha güvenlidir. Private signing key değerleri ise secret olarak doğru yönde yönetiliyor; workflow `ANDROID_KEY_PROPERTIES_B64` ve `ANDROID_KEYSTORE_B64` ile ephemeral dosya oluşturuyor.

### Mobil kimlik doğrulama

Mobil istemci access token’ı `flutter_secure_storage` üzerinden alıp her isteğe Bearer token olarak ekliyor ve 401 sonrasında refresh çağrısı yapıyor. Release build’lerde endpointin HTTPS olmasını ve localhost/emulator adresi olmamasını zorunlu kılan validation iyi bir korumadır. Ancak refresh başarısız olduğunda token temizleniyor; kullanıcıya görünür ve açıklayıcı bir yeniden giriş durumu sağlanmalıdır. Ayrıca gerçek cihazlarda cold-start, uyku/uyanma ve ağ değişimi senaryoları test matrisiyle doğrulanmalıdır.

### Görsel durum

Kullanıcı tarafından sağlanan admin ekran görüntüsünde genel grid, sol navigasyon, belge kartları ve Hata/Hazırlanıyor rozetleri tutarlı bir yönetim paneli dili oluşturuyor. Buna rağmen ikincil metinler ve kart alt bilgileri küçük ve düşük kontrastlı görünüyor; uzun belge adlarında kırpma/taşma davranışı ayrıca test edilmeli. Hata durumunda kartın yalnızca `Hata` göstermesi, kullanıcıya yeniden deneme sebebini göstermiyor; hata detayını güvenli biçimde açan bir drawer/modal ve `Yeniden dene` aksiyonu enterprise kullanım için gereklidir.

Android için tam görsel doğrulama yapılamadı; sandbox’ta Flutter SDK yok. Kullanıcı analiz çıktısı, kaynak kodun analiz aşamasında dahi iki hata verdiğini gösterdiğinden, gerçek cihaz görsel testinden önce bu iki hata düzeltilmelidir. Sonrasında en az küçük Android telefon, büyük Android telefon ve tablet/landscape için ekran görüntüsü alınmalı; özellikle ana sayfa başlığı, notification ikonuna yakınlığı, istatistik kartları, login, Google login, doküman viewer ve AI chat ekranları kontrol edilmelidir.

## Backend ve admin güvenlik denetimi

Backend’de `ValidationPipe` `whitelist`, `transform` ve `forbidNonWhitelisted` ile global etkin durumdadır. Helmet, HSTS, CSP, `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN` ve `Referrer-Policy: no-referrer` canlı endpointte doğrulanmıştır. Doküman controller sınıfı JWT ve role guard ile korunmakta; upload endpointi ayrıca `ADMIN` rolü istemekte ve 50 MB boyut sınırı uygulamaktadır. Kimliksiz doküman listesi isteğinin 401 dönmesi olumlu bir kontroldür.

Auth tarafında kayıt endpointi IP başına saatte 5, login endpointi IP başına dakikada 10 deneme ile sınırlandırılmıştır. Bu temel brute-force korumasıdır; ancak production proxy/Render arkasında istemci IP’sinin doğru algılandığı, dağıtık saldırılarda Redis veya merkezi rate-limit store kullanıldığı ve Google/phone endpointlerinin de abuse protection ile kapsandığı ayrıca doğrulanmalıdır.

`JWT_SECRET` production configuration validation içinde zorunludur ve `JwtStrategy` fallback secret kullanmamaktadır; bu doğru bir güvenlik davranışıdır. Buna karşılık refresh endpointinin hem HttpOnly cookie hem de Authorization Bearer refresh token kabul etmesi contract’ı genişletir. Admin paneli cookie-only, mobil istemci ise Bearer-only olacak şekilde ayrıştırılmalı; refresh token rotasyonu ve reuse detection eklenmelidir.

Repository’de `.env` dosyası, `key.properties` veya private key dosyası tracked görünmemektedir. `mobile/android/app/google-services.json` tracked durumdadır. Firebase Android configuration içindeki API key, Android istemcisinde bulunması gereken public client configuration’dır; yine de Google Cloud Console’da package name, SHA-1/SHA-256 ve API restriction uygulanmalıdır. Bu dosya bir Firebase service-account private key’i değildir. Buna karşın yanlışlıkla geçmişte private key commit edilip edilmediği GitHub Secret Scanning etkinleştirilmeden kesin olarak kanıtlanamamıştır.

## Çalışabilirlik ve CI/CD denetimi

Backend ve admin yerel sandbox koşularında başarılıdır. Buna karşılık GitHub Actions son koşularında `Continuous System Scan` ve `Mobile CI` başarısız durumdadır. Son Mobile CI job’ında failure noktası `Analyze` adımıdır ve hata mesajları kullanıcı ekindeki iki `invalid_constant` bulgusuyla aynıdır. Dolayısıyla “CI yeşil” kabulü yapılmamalıdır.

GitHub native Dependabot alerts repository için devre dışı veya API erişimi kısıtlı görünmektedir; Code Scanning ve Secret Scanning API istekleri de `403` ile okunamamıştır. Buna karşın yerel `npm audit` backend ve admin production bağımlılıklarında high/critical risk göstermemiştir. Bu iki kanıt birbirinin yerine geçmez: npm audit yalnızca npm ağacını kapsar; GitHub secret ve code scanning repository geçmişi ile workflow güvenliğini kapsar.

README’nin güncel olmayan bölümleri operasyonel risk oluşturmaktadır. README mobil platform klasörlerinin olmadığını, vector alanının `vector(1536)` olduğunu ve Voyage 3’ün 1024 boyut ürettiğini yazmaktadır. Güncel repository’de `mobile/android` ve Firebase yapılandırması bulunduğu, canlı RAG geçişinde `voyage-4-lite`/1024 uyumluluğunun hedeflendiği görülmektedir. Migration, release ve onboarding dokümanları tek bir güncel kaynakla eşleştirilmelidir.

## Önerilen düzeltme sırası

İlk olarak iki Flutter `invalid_constant` hatası düzeltilmeli ve GitHub Mobile CI yeniden yeşile döndürülmelidir. Aynı değişiklikte Flutter `use_build_context_synchronously` uyarıları ve en kritik deprecated API kullanımları temizlenmelidir; bütün const önerilerini aynı sprintte tamamlamak zorunlu değildir.

İkinci olarak versionCode kararı verilmelidir. Kullanıcının hedefi hâlâ 27 ise repository’deki 30 değişiklikleri geri alınmadan Play Console release yapılmamalıdır. Eğer Play Console’da 27’den yüksek bir sürüm zaten yüklüyse, mevcut build numarası korunup bir sonraki benzersiz sayı seçilmelidir. Workflow’un sabit `30` yerine kontrollü bir release input veya tek bir sürüm kaynağı kullanması gerekir.

Üçüncü olarak admin production bağlantısı düzeltilmelidir. `NEXT_PUBLIC_API_URL` production deploy’unda zorunlu hale getirilmeli, `/api/v1` relative fallback yalnızca aynı-origin reverse proxy kesin olarak mevcutsa kullanılmalıdır. Render `CORS_ORIGINS` içine admin domaini açıkça eklenmeli ve login, refresh, upload için production smoke test çalıştırılmalıdır.

Dördüncü olarak RAG işleme gerçek kuyruk modeliyle ele alınmalıdır. Voyage billing eklenmiş olsa da rate limit ve provider hataları per-document status’a yazılmalı, aynı dosyanın tekrar tekrar paralel işlenmesi engellenmeli, `Retry-After` başlığı dikkate alınmalı ve admin paneli kullanıcıya son hata sebebini göstermelidir. Hazır dokümanlar yeniden işlenmemeli; yalnızca Hata/İşleniyor durumundakiler seçici olarak yeniden denenmelidir.

Son olarak enterprise güvenlik tabanı tamamlanmalıdır. GitHub Dependabot, secret scanning ve code scanning etkinleştirilmeli; branch protection ile required checks zorunlu yapılmalı; production deploy yalnızca yeşil backend, admin ve mobile quality gate sonrasında mümkün olmalıdır. Ayrıca staging Render servisi üzerinde smoke/e2e testleri çalıştırılmalı, production’a doğrudan manuel env değişikliği yerine kayıtlı değişiklik süreci uygulanmalıdır.

## Sonuç

Sistem işlevsel bir prototipten production’a yaklaşmış durumdadır; backend, admin ve canlı endpoint kontrolleri olumlu sonuç vermektedir. Ancak **enterprise seviyeye hazır** demek için Android CI hatalarının temizlenmesi, versionCode 27/30 çelişkisinin çözülmesi, admin production API adresinin garanti altına alınması, README’nin güncellenmesi ve GitHub güvenlik kontrollerinin etkinleştirilmesi gerekir.

En acil iki karar şudur: **Android’in bir sonraki Play sürüm numarası kaç olacak** ve **admin production hangi kesin domain üzerinden backend’e bağlanacak**. Bu iki konu netleşmeden yeni AAB yayınlanmamalıdır.

## References

[1]: https://github.com/tuncak207-hue/bayi-teknik-destek-yeni-v1/blob/67a4ff0192a93f9bdbd4199ec2eeea4f6078b79b/mobile/lib/features/ai_assistant/ai_assistant_screen.dart#L159-L166 "AI assistant invalid_constant kaynağı"

[2]: https://github.com/tuncak207-hue/bayi-teknik-destek-yeni-v1/blob/67a4ff0192a93f9bdbd4199ec2eeea4f6078b79b/mobile/lib/features/auth/presentation/phone_login_screen.dart#L155-L164 "Phone login invalid_constant kaynağı"

[3]: https://github.com/tuncak207-hue/bayi-teknik-destek-yeni-v1/blob/67a4ff0192a93f9bdbd4199ec2eeea4f6078b79b/mobile/pubspec.yaml#L1-L8 "Android uygulama sürüm kaydı"

[4]: https://github.com/tuncak207-hue/bayi-teknik-destek-yeni-v1/blob/67a4ff0192a93f9bdbd4199ec2eeea4f6078b79b/.github/workflows/mobile-release.yml#L70-L106 "Production endpoint ve build number workflow’u"

[5]: https://github.com/tuncak207-hue/bayi-teknik-destek-yeni-v1/blob/67a4ff0192a93f9bdbd4199ec2eeea4f6078b79b/backend/src/main.ts#L7-L35 "CORS, Helmet, headers ve validation pipe"

[6]: https://github.com/tuncak207-hue/bayi-teknik-destek-yeni-v1/blob/67a4ff0192a93f9bdbd4199ec2eeea4f6078b79b/backend/src/documents/documents.controller.ts#L19-L48 "Doküman authorization ve upload sınırı"

[7]: https://github.com/tuncak207-hue/bayi-teknik-destek-yeni-v1/blob/67a4ff0192a93f9bdbd4199ec2eeea4f6078b79b/backend/src/auth/auth.controller.ts#L29-L116 "Auth throttling, refresh ve cookie ayarları"

[8]: https://docs.voyageai.com/docs/rate-limits "Voyage AI rate limits"

[9]: https://docs.github.com/en/code-security/dependabot/dependabot-alerts "GitHub Dependabot alerts"

[10]: https://docs.github.com/en/code-security/secret-scanning/introduction/about-secret-scanning "GitHub Secret Scanning"
