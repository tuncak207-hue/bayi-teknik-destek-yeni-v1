# Production Backend ve Android Release Runbook

## Amaç

Bu belge, NestJS backend’in HTTPS üzerinden canlıya alınmasını ve Flutter Android APK release sürecinin GitHub Actions ile güvenli biçimde çalıştırılmasını tanımlar. Gerçek parola, token, private key veya keystore içeriği bu belgeye yazılmamalıdır.

## GitHub Secrets sözleşmesi

Aşağıdaki değerler repository ayarlarında `Settings → Secrets and variables → Actions → Secrets` altında, tercihen `production` environment içinde tanımlanır.

| Secret | Değer biçimi | Zorunluluk |
|---|---|---|
| `MOBILE_API_BASE_URL` | `https://api.example.com/api/v1` | Zorunlu |
| `MOBILE_SOCKET_URL` | `https://api.example.com/chat` | Zorunlu |
| `FIREBASE_GOOGLE_SERVICES_JSON_B64` | `google-services.json` dosyasının base64 değeri | Zorunlu |
| `ANDROID_KEY_PROPERTIES_B64` | `mobile/android/key.properties` dosyasının base64 değeri | Zorunlu |
| `ANDROID_KEYSTORE_B64` | Release keystore dosyasının base64 değeri | Zorunlu |

Backend deployment platformunda ayrıca aşağıdaki runtime değişkenleri tanımlanmalıdır: `DATABASE_URL` transaction pooler (6543), `DIRECT_URL` session pooler (5432), `JWT_SECRET`, `CORS_ORIGINS`, `GOOGLE_CLIENT_ID`, `FIREBASE_CONFIG`, `STORAGE_ENDPOINT`, `STORAGE_REGION`, `STORAGE_ACCESS_KEY`, `STORAGE_SECRET_KEY`, `STORAGE_BUCKET`, `AI_API_KEY`, `AI_MODEL`, `EMBEDDING_PROVIDER`, `EMBEDDING_API_KEY` ve `EMBEDDING_MODEL`.

## HTTPS backend deployment sırası

Önce backend için bir HTTPS destekleyen hosting sağlayıcısı seçilir. Sağlayıcıda Node.js 22 uyumlu bir servis oluşturulur, repository’nin `backend` çalışma dizini seçilir ve build komutu `npm ci && npm run prisma:generate && npm run build`, başlatma komutu `npm run start:prod` olarak tanımlanır.

Deployment ortamına runtime değişkenleri eklenir. `DATABASE_URL` uygulama runtime’ı için Supabase transaction pooler portu 6543’ü, `DIRECT_URL` ise yalnızca Prisma migration işlemleri için session pooler portu 5432’yi kullanır. Migration işlemi deployment öncesi kontrollü olarak `npm run prisma:migrate:deploy` ile çalıştırılır.

Sağlayıcının verdiği HTTPS domain’i alındıktan sonra `CORS_ORIGINS` içine admin panelinin HTTPS adresi eklenir. Backend’in `/api/v1/health` endpoint’i `status: ok` ve `database: ok` döndürmeden mobil release çalıştırılmaz.

## Otomatik APK workflow’u

`.github/workflows/mobile-release.yml` workflow’u manuel çalıştırılabilir veya `v*` formatlı bir Git tag push edildiğinde otomatik çalışır. Workflow önce gerekli GitHub Secrets’ların boş olmadığını ve API/socket adreslerinin HTTPS kullandığını doğrular. Daha sonra Firebase dosyası, key properties ve keystore yalnızca runner üzerinde geçici olarak oluşturulur; repository’ye yazılmaz.

Release başlatmak için main branch güncelken sürüm tag’i oluşturulur:

```powershell
git switch main
git pull origin main
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions tamamlandığında signed APK workflow artifact’i olarak indirilir. Tag push edilmeden önce GitHub Secrets ve `production` environment değerleri kontrol edilmelidir.

## Güvenlik kuralları

Keystore, `key.properties`, Firebase servis hesabı JSON’u ve gerçek runtime secret’ları commit edilmemelidir. Secret değerleri sohbet, issue, PR açıklaması veya ekran görüntüsü üzerinden paylaşılmamalıdır. Production release başarısız olursa loglarda secret değerleri aranmaz; yalnızca secret adının eksik olduğu doğrulanır.

## Release kabul kriterleri

Release kabul edilmeden önce backend health endpoint’i başarılı olmalı, API smoke test geçmeli, Android signed APK build edilmelidir. Gerçek telefonda giriş, Google giriş, ana sayfa, istatistikler, Favorilerim, bildirimler, dosya yükleme ve çıkış akışları kontrol edilmelidir.

## PC gerektiren işler

Firebase dosyasının projeye kopyalanması, release keystore oluşturulması, GitHub Secrets için base64 değerlerinin hazırlanması ve gerçek cihaz APK kurulumu PC’de yapılmalıdır. Bu işlemlerde dosya içerikleri asistana gönderilmez; kullanıcı doğrudan kendi bilgisayarında ve GitHub hesabında işlem yapar.

---

**Yazar:** Manus AI

**Durum:** Production release hazırlık runbook’u
