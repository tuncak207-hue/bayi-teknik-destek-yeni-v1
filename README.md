# Yangın & Kamera Bayi Teknik Destek Uygulaması

Bayilerin, sisteme yüklenmiş teknik dokümanlara dayanarak AI'a soru sorabildiği,
cevabın hangi dokümandan/sayfadan geldiğini görebildiği ve diğer bayilerle
iletişim kurabildiği sistem.

**En önemli prensip: Dokümanda yoksa uydurma. Kaynak göster.**

---

## 1. Proje Yapısı

```
/backend    NestJS + Prisma + PostgreSQL (pgvector) — API, RAG, AI, chat (Socket.IO)
/admin      Next.js — basit admin paneli (Bayiler | Dokümanlar | Gruplar | Duyurular | Ayarlar)
/mobile     Flutter — iOS + Android bayi uygulaması
```

## 2. Bu Kod Tabanının Şu Anki Durumu (dürüst özet)

- **backend/**: Tüm modüller (auth, users, documents, rag, ai, chat, groups,
  community, notifications, announcements, search, calculators) gerçek,
  çalışan kodla yazıldı. `npm install` ve `npx tsc --noEmit` bu ortamda
  başarıyla çalıştırıldı ve derleme hatası yok. **Unit testler de bu ortamda
  gerçekten çalıştırıldı: 4 test suite, 18 test — hepsi geçti** (`npm test`).
  Testler auth akışını (PENDING/SUSPENDED/yanlış şifre/başarılı giriş), AI
  servisinin **uydurmama kuralını** (benzerlik eşiğinin altındaki chunk'ların
  kaynak olarak gösterilmemesi, dokümansız durumda güven seviyesinin LOW'a
  zorlanması, RAG bağlamının doğru şekilde promta eklenmesi), RAG chunking
  mantığını ve deterministik hesaplama formüllerini kapsıyor. **Ancak**
  `prisma migrate dev` bu sandbox'ta pgvector uzantılı Postgres'e erişemediği
  ve Prisma engine binary'lerini internetten tam indiremediği için (query
  engine .so dosyası 403 ile engellendi) çalıştırılamadı — TypeScript client
  kodu üretildi ama gerçek migration'ı kendi makinenizde yapmanız gerekiyor
  (adımlar aşağıda).
- **admin/**: `npm install` ve `npx next build` bu ortamda **başarıyla**
  tamamlandı, tüm 8 sayfa derlendi. Gerçek, production-build alınabilir kod.
- **mobile/**: Flutter bu sandbox'ta kurulu değil ve indirilemiyor (ağ erişimi
  paket registry'leriyle sınırlı), bu yüzden `flutter pub get` / `flutter
  analyze` / `flutter build` bu ortamda çalıştırılamadı. Kod backend API'sine
  birebir uyacak şekilde elle yazıldı — **gerçek zamanlı Socket.IO
  entegrasyonu dahil** (AI sohbeti ve bayi-bayi sohbeti artık
  `ChatGateway`'e bağlanıp `message:new` event'ini dinliyor, giriş yapınca
  otomatik bağlanıyor, çıkışta bağlantı kesiliyor). Ancak **siz kendi
  makinenizde** `flutter pub get` ve `flutter analyze` çalıştırıp olası küçük
  tip hatalarını (paket sürüm farkları vb.) düzeltmeniz gerekebilir.
  Ayrıca `android/` ve `ios/` platform klasörleri bu repoda yok; `flutter
  create .` ile üretmeniz gerekiyor (adım 5'te anlatılıyor).

---

## 3. Ön Gereksinimler

- Node.js 20+
- Docker (Postgres+pgvector ve MinIO için) veya kendi Postgres/S3 kurulumunuz
- Flutter SDK 3.3+ (mobil için)
- Anthropic API anahtarı (AI cevapları için)
- Voyage AI veya OpenAI API anahtarı (embedding için — Anthropic birinci taraf
  embedding modeli sunmuyor)
- (Opsiyonel) Firebase projesi (push bildirimleri için)

---

## 4. Backend Kurulumu

```bash
cd backend
cp .env.example .env
# .env dosyasını doldurun: DATABASE_URL, JWT_SECRET, AI_API_KEY,
# EMBEDDING_API_KEY, STORAGE_* değerleri

# Postgres (pgvector) + MinIO'yu Docker ile ayağa kaldırın
docker compose up -d

npm install

# pgvector uzantısını aktif et + vektör index'i oluştur
npx prisma migrate dev --name init
npx prisma db execute --file prisma/manual/001_pgvector.sql

# Admin kullanıcı + örnek grupları oluşturur (Yangın Alarm, Kamera, Honeywell, Hanwha, Teknik Destek)
SEED_ADMIN_EMAIL=admin@example.com SEED_ADMIN_PASSWORD=ChangeMe123! npm run prisma:seed

npm run start:dev
```

API şu adreste çalışır: `http://localhost:3000/api/v1`
WebSocket (chat) namespace: `http://localhost:3000/chat`

### Embedding sağlayıcısı hakkında not
Anthropic şu anda birinci taraf bir embedding modeli sunmuyor. `EMBEDDING_PROVIDER`
env değişkeni ile Voyage AI (`voyage`, Anthropic'in önerdiği ortak) veya OpenAI
(`openai`) arasında seçim yapabilirsiniz. Hangi modeli seçerseniz, embedding
boyutunu (`prisma/schema.prisma` içindeki `vector(1536)`) o modelin çıktı
boyutuyla eşleştirmeyi unutmayın (örn. `voyage-3` = 1024, `text-embedding-3-small` = 1536).

---

## 5. Admin Panel Kurulumu

```bash
cd admin
cp .env.local.example .env.local
npm install
npm run dev
```

Panel: `http://localhost:3001` — admin seed kullanıcısıyla giriş yapın.

---

## 6. Mobil Uygulama Kurulumu

Bu repo `mobile/lib` ve `mobile/pubspec.yaml` içerir ama platform klasörleri
(`android/`, `ios/`) yoktur. İlk kurulumda:

```bash
cd mobile
flutter create --org com.sirketiniz --project-name bayi_teknik_destek .
# Bu komut android/ ve ios/ klasörlerini üretir; lib/ ve pubspec.yaml'ı
# ÜZERİNE YAZMAZ ama olası çakışmalarda mevcut dosyalarınızı koruyun.

flutter pub get

# Firebase (push bildirimleri) için:
# 1. Firebase konsolunda proje oluşturun, Android/iOS uygulaması ekleyin
# 2. google-services.json -> android/app/
# 3. GoogleService-Info.plist -> ios/Runner/
# 4. main.dart içine Firebase.initializeApp() ekleyin (yorum satırı olarak bırakıldı)

flutter analyze   # olası küçük tip/sürüm hatalarını burada görüp düzeltin
flutter run --dart-define=API_BASE_URL=http://<backend-ip>:3000/api/v1 \
            --dart-define=SOCKET_URL=http://<backend-ip>:3000/chat
```

### Henüz eklenmemiş / genişletilmesi gerekenler (mobile)
- PDF görüntüleyicide gerçek sayfaya atlama (`document_viewer_screen.dart`
  içinde not edildi — `syncfusion_flutter_pdfviewer` veya `flutter_pdfview`
  eklenmeli)
- Socket.IO ile gerçek zamanlı mesaj güncellemesi (`chat_thread_screen.dart`
  şu an sadece REST ile çekiyor; `ChatGateway`'e bağlanıp `message:new`
  event'i dinlenmeli)
- Offline cache (favoriler, açılmış dokümanlar) — spesifikasyon §39
- Gerçek "beni" (current user id) provider'ı — birkaç ekranda placeholder var

---

## 7. Mimarinin Özeti

```
Doküman Yükleme (admin) → Text Extraction (PDF/DOCX/XLSX/OCR)
  → Chunking → Embedding → pgvector'a yazma

Bayi Sorusu → Vector Search (pgvector, marka/model filtresi)
  → İlgili chunk'lar sistem promptuna "BAĞLAM" olarak eklenir
  → Claude (Anthropic) cevap üretir, CONFIDENCE: HIGH/LOW döner
  → Sadece benzerlik eşiğini geçen chunk'lar "Kaynak" olarak gösterilir
  → Mesaj + kaynaklar veritabanına kaydedilir, WebSocket ile anlık yayınlanır
```

`AIProvider` interface'i (`backend/src/ai/providers/ai-provider.interface.ts`)
sayesinde LLM sağlayıcısı ileride değiştirilebilir; şu an tek implementasyon
`AnthropicProvider`.

---

## 8. Test

Backend'de gerçek, çalışan unit testler var (`src/**/__tests__/*.spec.ts`):

```bash
cd backend
npm test
```

Bu ortamda çalıştırıldığında sonuç: **4 test suite, 18 test — hepsi geçti.**
Kapsanan senaryolar:
- `auth.service.spec.ts`: kayıt (PENDING durumu), aynı e-posta ile ikinci
  kayıt engeli, PENDING/SUSPENDED bayinin giriş yapamaması, yanlış şifre,
  başarılı giriş ve token üretimi.
- `ai.service.spec.ts` — **en kritik test dosyası**: benzerlik eşiğinin
  altındaki chunk'ların kaynak olarak gösterilmediğini, hiç doküman
  bulunamadığında modelin "HIGH" demesine rağmen sistemin güven seviyesini
  "LOW"a zorladığını, model CONFIDENCE etiketi koymazsa güvenli tarafta
  kalıp LOW varsayıldığını ve RAG bağlamının doğru formatta (BAĞLAM/SORU)
  kullanıcı mesajına eklendiğini doğrular.
- `rag-ingestion.service.spec.ts`: uzun metnin doğru sayıda chunk'a
  bölündüğünü, boş sayfalar için embedding çağrılmadığını, her chunk'ın
  doğru sayfa numarasıyla kaydedildiğini doğrular.
- `calculators.service.spec.ts`: akü/HDD/PoE formüllerinin doğru sonuç
  verdiğini ve geçersiz girdilerde hata fırlattığını doğrular.

Manuel API testi için:

```bash
# Kayıt
curl -X POST localhost:3000/api/v1/auth/register -H "Content-Type: application/json" \
  -d '{"firstName":"Ali","lastName":"Yılmaz","company":"ABC Güvenlik","phone":"5551234567","email":"ali@abc.com","password":"Sifre1234"}'

# Admin ile onaylayın (admin token'ı /auth/login ile alın)
curl -X PATCH localhost:3000/api/v1/users/<user_id>/approve -H "Authorization: Bearer <admin_token>"

# Doküman yükleyin (admin), sonra AI'a soru sorun
curl -X POST localhost:3000/api/v1/ai/ask -H "Authorization: Bearer <dealer_token>" \
  -H "Content-Type: application/json" -d '{"question":"MA8000 panelinde loop cihazları görünmüyor, ne kontrol etmeliyim?"}'
```

---

## 9. Sıradaki Adımlar (öncelik sırasına göre)

1. ~~Backend Jest testleri~~ ✅ tamamlandı (auth, AI uydurmama kuralı, RAG chunking, hesaplamalar)
2. ~~Flutter tarafında gerçek zamanlı Socket.IO entegrasyonu~~ ✅ tamamlandı
   (`core/api/socket_service.dart` — AI sohbeti ve bayi-bayi sohbeti artık
   canlı; giriş yapınca otomatik bağlanır, çıkışta bağlantı kesilir)
3. PDF viewer'da sayfa-atlama (`syncfusion_flutter_pdfviewer` veya
   `flutter_pdfview` entegrasyonu — `document_viewer_screen.dart` içinde
   yer tutucu bırakıldı)
4. Offline cache (favoriler, açılmış dokümanlar — spesifikasyon §39)
5. CI/CD (GitHub Actions) — lint + test + build
6. Backend e2e testleri (gerçek Postgres+pgvector ile, Docker test container)
7. Gerçek "current user id" provider'ı mobilde (birkaç ekranda placeholder
   karşılaştırma var — `senderType == 'USER'` yerine gerçek userId
   karşılaştırması gerekiyor)
