# Karmaşık Kart Refaktörü, Performans ve UI Test Raporu

**Tarih:** 25 Ağustos 2026  
**Kapsam:** Flutter mobil uygulaması  
**Referans:** `Randevu Al` kartındaki merkezî ikon–başlık–açıklama–metadata–aksiyon kompozisyonu

## Yönetici özeti

BOM liste kartı ve topluluk detay ekranındaki ana paylaşım/yorum kartları, ortak `ReferenceCardContent` bileşenine geçirildi. `StandardCard` ve `ReferenceCardContent` içinde tekrarlanan tema çözümlemeleri azaltıldı; `StandardCard` için Material/InkWell radius değerleri aynı kaynağa bağlandı. Merge edilmiş önceki sürümün CI kontrolünde gerçek bir sözdizimi hatası tespit edildi ve `AppEmptyState` içindeki fazladan kapanış parantezi giderildi.

Bununla birlikte GitHub Actions mobil CI, repository’deki mevcut analyzer politikasında bulunan **125 adet yalnızca `info` seviyesindeki lint bulgusu** nedeniyle başarısız olmaktadır. Bu nedenle PR #19 henüz merge edilmemiştir. Test ve Android debug build adımları analyzer başarısızlığından dolayı çalıştırılmamıştır. Yerel sandbox ortamında Flutter SDK bulunmadığından cihaz/emülatör üzerinde golden screenshot veya gerçek render testi yapılamamıştır.

> **Sonuç:** Refaktör kodunda önceki merge’de görülen sözdizimi hatası düzeltilmiştir; ancak görsel bozulma olmadığına dair tam kanıt için CI analyzer politikasının düzeltilmesi ve ardından Flutter test/build adımlarının tamamlanması gerekmektedir.

## Uygulanan karmaşık kart refaktörleri

| Dosya | Dönüşüm | Korunan işlevler |
|---|---|---|
| `mobile/lib/features/bom/bom_builder_screen.dart` | BOM listeleri merkezî ikon, başlık, lokasyon, kalem sayısı, güncelleme tarihi ve alt aksiyon düzenine alındı | Liste açma ve silme |
| `mobile/lib/features/community/community_post_screen.dart` | Paylaşım kartı ve yorum kartları merkezî düzene alındı; AI içerik için Markdown render korundu | AI’dan yardım isteme, yorum ekleme, yorum silme |
| `mobile/lib/core/widgets/app_components.dart` | `AppEmptyState`, `ReferenceCardContent` kullanacak biçimde düzeltildi; CI sözdizimi hatası giderildi | Boş durum semantiği ve opsiyonel aksiyon |
| `mobile/lib/core/widgets/design_system.dart` | `StandardCard` tema/radius hesapları tekil yerel değişkenlerle sadeleştirildi | Kart yüzeyi, dokunma ve InkWell davranışı |

## Performans ve render incelemesi

### Olumlu bulgular

`ReferenceCardContent` zaten `StatelessWidget` olduğu için kart içeriğinde gereksiz state yaşam döngüsü bulunmamaktadır. `mainAxisSize: MainAxisSize.min` kullanımı kartın içeriğin gerektirdiğinden fazla dikey alan ayırmasını önlemektedir. `const SizedBox` aralıklarının kullanılması sabit aralık widget’larının yeniden oluşturulma maliyetini düşük tutmaktadır.

`StandardCard` içinde `Theme.of(context)` ve `colorScheme` artık tek build çağrısında çözülmektedir. Bu, görsel sonucu değiştirmeden tekrarlanan tema erişimlerini azaltır. Kartın Material ve InkWell katmanları aynı `BorderRadius` nesnesini kullandığı için dokunma ripple alanı ile görsel kart yüzeyi arasında keskin köşe/taşma riski azaltılmıştır.

Liste ekranlarının ana listeleri `ListView.builder`, `ListView.separated` veya `GridView.builder` kullanmaktadır. Bu, bütün kartların tek seferde inflate edilmesi yerine görünür içerik etrafında lazy build yapılmasını sağlar. Karmaşık ekranlarda mevcut builder yaklaşımı korunmuştur.

### İzlenmesi gereken riskler

`ReferenceCardContent` her kart için ikon, başlık, açıklama, metadata ve aksiyon widget ağacını yeniden kurar. Bu normal Flutter listeleri için beklenen davranıştır; ancak yüzlerce kart içeren ekranlarda profile mode ile frame time, raster time ve rebuild count ölçülmelidir. Bu aşamada `RepaintBoundary` eklenmemiştir; çünkü her karta körlemesine boundary eklemek bellek ve compositing maliyetini artırabilir.

Kartların metadata ve aksiyon alanlarında `Wrap`, `Column`, `MarkdownBody` ve `IconButton` kombinasyonları kullanılmaktadır. Küçük ekranlarda taşma ve yüksek kart boyu açısından özellikle topluluk AI yorumları, BOM lokasyon metinleri ve ayarlar kartları kontrol edilmelidir. `ReferenceCardContent` açıklamayı üç satırla sınırlar; bu, kart yüksekliğini kontrol eder ancak uzun açıklamanın görsel olarak kesilmesine neden olabilir.

Repository’nin mobil CI çıktısında mevcut genel lint bulguları içinde `prefer_const_constructors` gibi performans önerileri bulunmaktadır. Bunlar doğrudan yeni refaktörün render hatası değildir; ancak CI’nin `flutter analyze` adımını başarısız duruma düşürmektedir.

## Merge edilmiş kod için UI bozulma testleri

| Kontrol | Sonuç | Açıklama |
|---|---|---|
| Merge edilmiş önceki main CI | Başarısız | `Analyze` adımında `app_components.dart:483` civarında fazladan parantez nedeniyle sözdizimi hatası bulundu |
| AppEmptyState düzeltmesi | Düzeltildi | Fazladan kapanış parantezi kaldırıldı; kullanılmayan `scheme` değişkeni temizlendi |
| `git diff --check` | Başarılı | Boşluk ve patch biçimi hatası bulunmadı |
| UI-only kapsam kontrolü | Başarılı | Değişiklikler yalnızca `mobile/lib` altındaki UI/widget dosyalarında |
| Backend/admin/API değişikliği | Bulunmadı | `backend/`, `admin/` veya API katmanı değişmedi |
| PR #19 CI Analyze | Başarısız | 125 adet `info` lint bulgusu raporlandı; test ve Android build adımları skip edildi |
| Flutter unit/widget test | Çalıştırılamadı | CI analyzer başarısız olduğu için test adımı çalışmadı; sandbox’ta Flutter SDK yok |
| Android debug build | Çalıştırılamadı | CI analyzer başarısız olduğu için build adımı çalışmadı |
| Golden screenshot / gerçek cihaz görsel testi | Çalıştırılamadı | Sandbox’ta Flutter SDK/emülatör ve golden test altyapısı mevcut değil |

## CI ayrıntısı

GitHub Actions workflow sırası `Install dependencies → Analyze → Test with coverage → Verify Android debug build` şeklindedir. `Analyze` başarısız olduğu için sonraki iki adım çalıştırılmamıştır. PR #19’daki güncel çalışma:

- **PR:** [#19 – Refactor complex mobile card layouts](https://github.com/tuncak207-hue/bayi-teknik-destek-yeni-v1/pull/19)
- **Commit:** `a39a983`
- **CI run:** [32889942213](https://github.com/tuncak207-hue/bayi-teknik-destek-yeni-v1/actions/runs/32889942213)
- **CI sonucu:** `Analyze` başarısız; `Test with coverage` ve `Verify Android debug build` atlandı.

## Açık kalan işler ve önerilen sonraki adım

PR #19, CI kırmızı olduğu için merge edilmeden açık bırakılmıştır. Öncelikli teknik iş, CI’nin `flutter analyze` adımını yalnızca gerçek `warning` ve `error` seviyelerinde başarısız kılacak şekilde lint politikasını netleştirmek veya mevcut 125 bilgi seviyesindeki lint bulgusunu toplu olarak temizlemektir. Ardından analyzer yeniden çalıştırılmalı, widget testleri ve Android debug build tamamlanmalıdır.

Görsel doğrulama için gerçek Flutter ortamında aşağıdaki ekranlar küçük, orta ve büyük cihaz genişliklerinde kontrol edilmelidir: BOM listesi ve BOM oluşturma ekranı, topluluk paylaşım detayı, AI yorumu, yorum silme durumu, boş liste durumu ve ayarlar kartları. Kontrol sırasında taşma, metin kesilmesi, kartların aşırı uzaması, aksiyonların ekran dışına taşması ve InkWell ripple köşe uyumu gözlenmelidir.

## Değişiklik durumu

| Bilgi | Değer |
|---|---|
| Branch | `feat/unify-all-card-interiors` |
| Son commit | `a39a983` |
| PR durumu | Açık, CI başarısız olduğu için merge edilmedi |
| Merge güvenliği | CI yeşil olmadan merge önerilmiyor |

Bu rapor, testlerin çalıştırılamadığı noktaları başarılıymış gibi göstermemek için açıkça ayırmaktadır. Özellikle golden screenshot ve gerçek cihaz doğrulaması yapılmadan “kesinlikle görsel bozulma yoktur” sonucu çıkarılmamıştır.
