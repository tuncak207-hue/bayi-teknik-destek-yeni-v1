# Supabase + Prisma bağlantı rehberi

Bu backend, Supabase PostgreSQL üzerinde çalışacak şekilde Prisma `postgresql` provider kullanır. Supabase proje URL’si (`https://<project-ref>.supabase.co`) API base URL değildir; Flutter ve admin uygulamaları NestJS backend’in public HTTPS adresine bağlanır.

## 1. Supabase bağlantı bilgilerini al

Supabase Dashboard → **Connect** bölümünden PostgreSQL connection string’ini al. Backend’in sürekli çalışan bir sunucu/container üzerinde çalışması için direct connection veya IPv4 uyumluluğu gereken ortamlarda Supavisor session pooler bağlantısı kullanılmalıdır.

`DATABASE_URL` değerini connection string içinde parola ile birlikte tanımla. Parolada `@`, `#`, `%`, `/` gibi URL özel karakterleri varsa percent-encoding uygulanmalıdır.

Örnek biçim:

```dotenv
DATABASE_URL="postgresql://postgres:<ENCODED_PASSWORD>@db.<PROJECT_REF>.supabase.co:5432/postgres?schema=public&sslmode=require"
```

Supabase Dashboard’dan alınan gerçek bağlantı string’ini repository’ye, Flutter’a veya client-side admin bundle’ına yazma.

## 2. Local migration ve Prisma doğrulaması

Backend klasöründe gerçek secret’ları yalnızca yerel `.env` dosyasına koy. `.env` dosyası gitignore kapsamındadır.

```powershell
cd backend
npm install
npm run prisma:generate
npm run prisma:migrate:deploy
npm run build
npm test -- --runInBand
```

İlk bağlantı doğrulamasında migration çalıştırmadan önce Supabase Dashboard’daki database bağlantısının aktif olduğundan emin ol.

## 3. Production güvenlik kuralları

`DATABASE_URL`, JWT secret, Firebase service account ve storage secret’ları yalnızca backend deployment environment’ında tutulmalıdır. Bu değerler Flutter uygulamasına, Next.js client bundle’ına, GitHub issue/PR metnine veya public loglara konulmamalıdır.

Supabase secret/service key yanlışlıkla paylaşıldıysa Supabase Dashboard’dan hemen rotate/revoke edilmelidir. Yeni secret GitHub Actions secret olarak yalnızca gerçekten server-side bir job ihtiyaç duyuyorsa tanımlanmalıdır.

## 4. Uygulama API adresi

Flutter’daki `MOBILE_API_BASE_URL` Supabase proje URL’si değildir. Bu değişken NestJS backend’in public HTTPS adresini içermelidir:

```text
https://<public-backend-domain>/api/v1
```

Backend henüz Render, Railway, VPS veya başka bir hosting üzerinde yayınlanmadıysa production smoke testi çalıştırılamaz. Local geliştirmede backend adresi `http://localhost:3000/api/v1` olabilir; bu production adresi değildir.

## 5. Bağlantı modeli notu

Mevcut proje Prisma 5.x ile yalnızca `DATABASE_URL` datasource URL’sini kullanır. Bu nedenle ilk güvenli geçişte Supabase Dashboard’dan alınan ve deployment ortamına uygun olan tek bağlantı string’i `DATABASE_URL` olarak tanımlanmalıdır. Pooled runtime bağlantısı ile ayrı direct migration bağlantısına geçilecekse Prisma sürümü, schema datasource tanımı ve CI secret’ları birlikte güncellenmeli; bu değişiklik ayrı bir migration PR’ında test edilmelidir.
