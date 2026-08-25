# Admin Paneli UX Sadeleştirme Analizi

## Kapsam

Bu inceleme yalnızca `admin/` klasörünü kapsar. Mobil, backend ve API dosyaları değerlendirme kapsamına alınmamıştır. Admin panelinde 19 işlevsel sayfa, ortak `AppShell`, `Sidebar`, `Topbar` ve ortak UI primitive’leri incelenmiştir.

## Genel değerlendirme

Admin panelinin ortak shell’i son tasarım güncellemesiyle daha sade bir temele kavuşmuştur. Buna rağmen sayfa seviyesinde ortak tasarım sistemini bypass eden çok sayıda yerel sınıf bulunuyor. Özellikle `bg-white`, `rounded-xl`, `rounded-2xl`, `shadow-sm` ve farklı padding kombinasyonları sayfalar arasında görsel yoğunluk farkı oluşturuyor. En önemli UX fırsatı, bilgi yoğun ekranlarda aynı verinin farklı kartlarda tekrar edilmesini azaltmak ve her sayfada tek bir ana işlem alanı oluşturmaktır.

## Önceliklendirilmiş öneriler

| Öncelik | Alan | Bulgu | Öneri | Kullanıcı etkisi |
|---|---|---|---|---|
| P0 | Dashboard | Üst KPI kartları daha önce alt bölüm metriklerini tekrar ediyordu; bu dalgada kaldırıldı. | Dashboard’da tekil metrik kaynağı korunmalı; yeni üst kart eklenmemeli. | Bilgi tekrarını ve tarama süresini azaltır. |
| P1 | Bayiler | Liste, arama, detay modalı ve düzenleme formu aynı anda yoğun bilgi gösteriyor. | Listeyi tek ana tablo/kart listesi yapın; detay ve düzenlemeyi tek drawer içinde sekmeli veya bölümlü gösterin. | Bayi seçme ve işlem yapma süresi azalır. |
| P1 | Randevular | Tablo satırlarında durum, tarih ve aksiyonlar aynı yatay yoğunlukta; küçük ekranlarda tarama zorlaşıyor. | Durum filtresini üstte sabitleyin, varsayılan görünümde yalnızca tarih–bayi–durum–ana aksiyon gösterin; ikincil detayları drawer’a taşıyın. | Kritik randevuları daha hızlı bulmayı sağlar. |
| P1 | Teknik Destek | Form alanları ve maliyet/ölçüm bölümleri tek sayfada uzun bir akış oluşturuyor. | Formu “Talep”, “Teknik ayrıntı”, “Maliyet” bölümlerine ayırın; yalnızca ilgili bölüm açılır olsun. | Form terk oranını ve bilişsel yükü azaltır. |
| P1 | Bayi Ziyaretleri | Sayfa 792 satırla panelin en karmaşık ekranı; çok sayıda filtre, form, modal ve veri bölümü içeriyor. | Ziyaret listesi, yeni ziyaret formu ve rapor özetini üç ayrı görünür alana ayırın; detay formunu drawer’a taşıyın. | Karmaşık işlemlerde yön kaybını önler. |
| P1 | Dokümanlar | Yükleme formu, arama/filtre ve doküman kartları aynı görsel ağırlığa sahip. | “Doküman ekle” işlemini belirgin tek CTA yapın; kartlarda yalnızca başlık, tür, işlenme durumu ve menü gösterin. | Ana görev daha kolay bulunur. |
| P1 | Teklifler | Excel içe aktarma, PDF fiyat listesi, teklif listesi ve düzenleme formu aynı ekranda yarışıyor. | İçe aktarma işlemlerini ayrı bir “İçe aktar” dialog’una alın; ana ekranda teklif listesi + tek CTA bırakın. | Ana iş akışı sadeleşir. |
| P2 | Satış Danışmanları | Liste ve düzenleme modalı tekrar eden alanlar içeriyor. | Satır içi hızlı durum bilgisi, detay drawer’ı ve tek bir düzenle aksiyonu kullanın. | Daha az modal geçişi sağlar. |
| P2 | Gruplar | Basit CRUD işlemi için büyük kart/modal ağırlığı var. | Listeyi kompakt tabloya indirin; ekle/düzenle işlemlerini küçük dialog’da tutun. | Basit işlem gereksiz görsel yük taşımaz. |
| P2 | Eğitim Merkezi | Yükleme formu ve içerik kartları geniş alan kullanıyor; kartlarda tekrar eden metadata bulunuyor. | Kategori filtresini üst toolbar’a taşıyın; kartlarda başlık, tür ve tek menü aksiyonu bırakın. | İçerik taraması hızlanır. |
| P2 | Sohbetler | Sohbet listesi, ban yönetimi ve detay içeriği aynı hiyerarşide görünüyor. | Sol liste–sağ detay iki panelli düzene geçin; ban işlemlerini detay header’ında gruplayın. | Moderasyon akışını hızlandırır. |
| P2 | Analiz ekranları | Operasyon ve ürün analizi farklı kart stilleri ve başlık yoğunlukları kullanıyor. | Her analiz ekranında aynı şablonu kullanın: başlık, dönem filtresi, üç KPI, ana grafik/tablo, detaylar. | Öğrenme maliyetini azaltır. |
| P2 | Duyurular ve Slaytlar | İçerik oluşturma ve mevcut içerik listesi aynı yüzeyde fazla yer kaplıyor. | Oluşturma işlemini dialog’a taşıyıp listeyi ana ekran yapın; önizleme ve durum badge’i korunsun. | İçerik yönetimi daha hızlı olur. |
| P3 | İşlem Günlüğü | Salt tablo görünümü filtreleme ve satır ayrıntısı açısından sınırlı. | Tarih, kullanıcı ve işlem türü filtrelerini tek toolbar’da toplayın; ayrıntıyı expandable row yapın. | Denetim aramalarını kolaylaştırır. |
| P3 | Pasif Bayiler | Basit liste için grid/kart yaklaşımı gereğinden fazla görsel alan kullanıyor. | Kompakt tablo ve tek “yeniden aktifleştir” aksiyonu kullanın. | Liste daha hızlı taranır. |
| P3 | Ayarlar | Az sayıda ayar için kartların görsel ağırlığı yüksek. | Ayarları “Genel”, “Bildirimler”, “Güvenlik” bölümlerinde sade liste olarak sunun. | Yönetim hissi daha anlaşılır olur. |

## Bayiler sayfası için önerilen akış

Bayiler ekranında varsayılan görünüm yalnızca arama, durum filtresi, bayi adı, şehir, durum ve tek ana aksiyon göstermelidir. Bayi seçildiğinde sağdan açılan drawer içinde özet bilgiler, iletişim, durum geçmişi ve işlemler bölümlenmelidir. Silme veya askıya alma gibi yıkıcı işlemler drawer’ın en altında ve açık uyarıyla gösterilmelidir. Böylece liste ile detay aynı anda üst üste binmez.

## Randevular sayfası için önerilen akış

Randevular ekranında ilk satırda dönem, durum ve bayi filtreleri bulunmalıdır. Varsayılan tablo sütunları bayi, randevu tarihi, tür, durum ve ana işlem olmalıdır. Notlar, konum ayrıntısı ve geçmiş bilgiler satır içine doldurulmamalı; detay drawer’ında gösterilmelidir. Bekleyen randevular için tek bir görsel vurgu kullanılmalı, aynı satırda birden fazla kırmızı/amber uyarı tekrarlanmamalıdır.

## Teknik destek ve bayi ziyaretleri için önerilen akış

Bu iki ekran veri ve form yoğunluğu nedeniyle kartları azaltmaktan çok aşamalı akış gerektiriyor. Yeni kayıt formu ayrı bir drawer veya dialog içinde açılmalı; liste ekranı yalnızca filtre, durum ve özet bilgilerden oluşmalıdır. Form alanları mantıksal bölümlere ayrılmalı ve isteğe bağlı alanlar varsayılan olarak kapalı tutulmalıdır. Bu yaklaşım iş mantığını değiştirmez; yalnızca aynı API çağrılarını daha anlaşılır bir arayüzde sunar.

## Ortak tasarım kuralları

Admin sayfalarında tek bir ana Card primitive’i kullanılmalı ve sayfa içinde tekrar tekrar `bg-white rounded-xl` gibi yerel kombinasyonlar yazılmamalıdır. Kartlarda varsayılan padding `16px`, başlık alanlarında `12px–16px`, radius değerinde `8px–12px` aralığı korunmalıdır. Her ekranda yalnızca bir birincil brand CTA bulunmalı; diğer işlemler ikincil buton veya üç nokta menüsünde gruplanmalıdır.

Tabloların mobil görünümünde yatay taşma yerine önemli alanlar görünür bırakılmalı, ikincil alanlar detay drawer’ına taşınmalıdır. Loading, empty ve error durumları ortak primitive’lerle gösterilmelidir. Yıkıcı işlemler her zaman son onay dialog’u ve açık eylem metniyle korunmalıdır.

## Uygulama sırası

İlk dalga olarak Bayiler, Randevular, Teknik Destek ve Bayi Ziyaretleri ekranları ele alınmalıdır. İkinci dalgada Dokümanlar, Teklifler, Eğitim Merkezi ve Sohbetler sadeleştirilmelidir. Son dalgada düşük yoğunluklu Gruplar, Pasif Bayiler, Ayarlar, Duyurular, Slaytlar ve İşlem Günlüğü ekranları ortak toolbar ve liste kalıplarına geçirilmelidir.

Bu rapor öneri aşamasındadır; bu turda yalnızca analiz yapılmış, sayfa iş mantığında veya API sözleşmelerinde değişiklik yapılmamıştır.
