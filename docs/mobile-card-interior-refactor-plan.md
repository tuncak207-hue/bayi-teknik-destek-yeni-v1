# Tüm Mobil Kartların Randevu Al Referansına Dönüştürülmesi

## Referans kompozisyon

Tüm kartların ortak iç kompozisyonu şu kurallara bağlanacaktır: kart içeriği yatay olarak merkezlenecek; ikon veya görsel üstte sabit ölçülü bir dairesel alan içinde yer alacak; başlık ikonun altında merkez hizalı olacak; açıklama başlığın altında merkez hizalı ve kontrollü satır genişliğinde olacak; varsa sayaç veya durum rozeti başlık satırının sağında değil, başlık altında veya kartın üst sağ köşesinde ortak bir rozet bileşeni olarak görünecek; aksiyonlar kartın altında merkezlenmiş, aynı genişlik ve dokunma alanına sahip olacak; tüm kartlarda aynı iç padding, radius, border ve gölge kullanılacaktır.

## Dönüşüm planı

| Sıra | Ekran/kart grubu | Mevcut iç yapı | Yapılacak değişiklik |
|---|---|---|---|
| 1 | `Randevularım` boş durum kartı | Zaten ikon + başlık + açıklama merkezli `AppEmptyState` | Referansın altın bileşeni yapılacak; tüm boş durumlar bu bileşeni kullanacak |
| 2 | Ana sayfa `BU AY` kartları | İkon + sayı + etiket dikey kolonda | İkon dairesi, merkez sayı, merkez etiket ve ortak yükseklik `ReferenceCardContent` içine alınacak |
| 3 | Ana sayfa hızlı işlem kartları | İkon dairesi + işlem etiketi | Aynı `ReferenceCardContent` kullanılacak; ikon, başlık ve opsiyonel açıklama merkezlenecek |
| 4 | Ana sayfa AI banner’ı | Yatay ikon + başlık/açıklama + ok | Banner korunacak ancak ortak kart yüzeyi, padding ve merkez dikey hizaya geçirilecek; yatay yapı yalnız hero özelliği olarak kalacak |
| 5 | Arama sonuç kartları | Avatar/ikon solda, metin ortada, chevron sağda | Avatar üstte merkez ikon alanına, başlık ve özet altına taşınacak; chevron merkez aksiyonuna dönüştürülecek |
| 6 | Mesaj/conversation kartları | Avatar + son mesaj + zaman + unread badge yatay | Avatar üstte, konuşma başlığı ve son mesaj merkezde; zaman/badge kart üst sağında ortak rozet olarak konumlanacak |
| 7 | Favori ve doküman kartları | Thumbnail/ikon + başlık + metadata yatay | Thumbnail ikon dairesine dönüştürülecek; başlık, marka ve metadata merkezlenecek; açma/indirme aksiyonu altta ortalanacak |
| 8 | Gruplar, bayiler ve takım kartları | Avatar + isim/rol/üye bilgisi yatay | Avatar üstte; isim ve rol merkezde; detay/katıl aksiyonu altta merkezde olacak |
| 9 | Destek talebi kartları | Başlık, durum, tarih, açıklama ve aksiyonlar bilgi yoğun | İkon/durum üstte; başlık ve açıklama merkezde; tarih ve durum ortak metadata satırına; aksiyonlar alta alınacak |
| 10 | Acil destek/satış destek banner’ları | Renkli yatay hero kartları | Referans yüzey sistemi ve merkez iç padding uygulanacak; yalnız acil durum için vurgu rengi korunacak |
| 11 | Teklif, komisyonlama ve ziyaret kartları | Başlık, durum, tarih, işlem aksiyonları yatay | Ortak merkez bilgi kartına dönüştürülecek; durum rozeti üst sağ, ana bilgi merkez, aksiyon alt merkez olacak |
| 12 | Eğitim ve duyuru kartları | Başlık, kategori, ilerleme/aksiyon | İkon/kategori üstte; başlık ve açıklama merkezde; ilerleme ve CTA alt merkezde olacak |
| 13 | Ayarlar kartları | `SwitchListTile` / `ListTile` ile kontrol sağda | Kart başlığı ve açıklaması merkeze alınacak; switch/slider alt merkez aksiyon alanına taşınacak |
| 14 | Randevu dolu kartları | Durum + konu + tarih + açıklama + aksiyonlar | Takvim ikonu üstte; konu ve özet merkezde; tarih/durum metadata satırı; detay/iptal aksiyonları altta merkezde |
| 15 | Randevu formu | Dikey form alanları | Form alanlarının dış kartı referans yüzeyde kalacak; alan başlıkları ve submit aksiyonu aynı merkez/grid ritmine geçirilecek |

## Ortak bileşenler

`ReferenceCardContent` bütün kartların ikon–başlık–açıklama–metadata–aksiyon sıralamasını yönetecektir. `ReferenceCardSurface` yüzey, border, radius, gölge ve padding değerlerini yönetecektir. `ReferenceCardBadge` durum/sayaçları ortaklaştıracaktır. Mevcut iş mantığı, API, auth, socket, repository ve backend akışlarına dokunulmayacaktır.

## Doğrulama

Kod değişiklikleri yalnızca `mobile/` altında tutulacak; `git diff --check` çalıştırılacak; Dart dosyalarının widget kapanışları kontrol edilecek; değişiklikler ayrı commit olarak kaydedilecektir. Bu aşamada push veya merge yapılmayacaktır.
