# ENTPA Bayi Teknik Destek Uygulaması
## KVKK Aydınlatma Metni

**Son güncelleme:** 29 Ağustos 2026

> **Hukuki not:** Bu metin, mevcut uygulama özellikleri ve teknik veri modelleri esas alınarak hazırlanmış bir çalışma metnidir. Yayımlanmadan veya kullanıcılara sunulmadan önce ENTPA Elektronik Cihazlar Tic. Paz. ve Turizm A.Ş.’nin hukuk/uyum sorumlusu veya KVKK alanında yetkin bir avukat tarafından gerçek veri akışları, hizmet sağlayıcıları, yurt dışı aktarım mekanizmaları, saklama-imha politikası ve çalışan/bayi süreçleriyle doğrulanmalıdır.

## 1. Veri sorumlusu

6698 sayılı Kişisel Verilerin Korunması Kanunu (“KVKK”) kapsamında, bu Aydınlatma Metni’nde belirtilen kişisel veriler bakımından veri sorumlusu **ENTPA Elektronik Cihazlar Tic. Paz. ve Turizm A.Ş.**’dir.

**Adres:** Y. Dudullu OSB. 1. Cadde No: 23, 34775 Ümraniye – İstanbul / TR  
**E-posta:** ekerim@entpa.com.tr

## 2. Aydınlatma metninin amacı

Bu metin, ENTPA Bayi Teknik Destek mobil uygulaması ve bağlı teknik destek iş süreçlerinde kişisel verilerin hangi amaçlarla işlendiğini, kimlere ve hangi amaçla aktarılabileceğini, veri toplama yöntemini ve ilgili kişinin haklarını açıklamak amacıyla hazırlanmıştır. Bu metin bir açık rıza metni değildir. Açık rıza gerektiren ayrı bir işleme faaliyeti varsa, ilgili faaliyete özgü açık rıza ayrıca alınır.

## 3. İşlenen kişisel veri kategorileri

Uygulamanın özelliğine, kullanıcının rolüne ve kullanıcının yaptığı işleme göre aşağıdaki kişisel veriler işlenebilir:

| Kategori | İşlenen veri örnekleri |
|---|---|
| Kimlik bilgileri | Ad, soyad, Google hesap kimliği ve gerektiğinde müşteri/iletişim kişisinin adı |
| İletişim bilgileri | E-posta, telefon, müşteri veya bayi iletişim kişisine ait telefon/e-posta |
| Kuruluş ve mesleki bilgiler | Şirket/bayi adı, kullanıcı rolü, uzmanlık etiketleri, ekip ve yetkilendirme bilgileri, iletişim kişisinin unvanı |
| Hesap ve işlem güvenliği | Kullanıcı hesabı, parola özeti, oturum/JWT bilgileri, hesap durumu, son giriş zamanı, audit ve güvenlik kayıtları |
| Teknik destek ve saha verileri | Ürün adı, model, seri numarası, tesis/lokasyon bilgisi, teknik açıklama, arıza, öncelik, durum, SLA, eskalasyon, ölçüm ve parça kayıtları |
| İş ve operasyon verileri | Randevu türü, tarih/saat, il/ilçe, bayi ziyareti, proje, görüşme konusu, takip aksiyonu, notlar ve teklif bilgileri |
| Finansal nitelikte olabilecek iş verileri | Teklif toplamı, ürün kalemleri, miktar, birim fiyat, maliyet ve tahmini proje tutarı; ödeme hesabı veya kart bilgisi işlenmez |
| Görsel ve dosya verileri | Destek fotoğraf/video ekleri, önce/sonra fotoğrafları, PDF/doküman, sertifika, eğitim dosyası, müşteri imzası ve saha dosyaları |
| İletişim içerikleri | Doğrudan/grup/AI sohbet mesajları, topluluk gönderileri, yorumlar, teknik notlar, geri bildirim ve mesaj tepkileri |
| Bildirim verileri | Firebase bildirim token’ı, bildirim tercihleri, sessiz saatler, okundu/okunmadı ve bildirim geçmişi |
| Kullanım tercihleri | Dil, karanlık mod, favoriler, sabitlenen kayıtlar, arşivleme, okuma ve bildirim tercihleri |

Uygulama, mevcut işlevleri bakımından kamera, mikrofon, kişi rehberi veya kesin konum izni gerektirmeyecek şekilde tasarlanmıştır. Kullanıcı bir dosya veya fotoğraf yüklerse, ilgili içeriğin kişisel veri içerebileceğini kabul ederek yalnızca iş süreci için gerekli içeriği yüklemelidir. Kimlik, sağlık, biyometrik veya başka özel nitelikli veri içeren dosyalar talep edilmedikçe yüklenmemelidir.

## 4. Kişisel verilerin işlenme amaçları

Kişisel veriler aşağıdaki amaçlarla işlenir:

1. Kullanıcı hesabı oluşturmak, Google ile girişi ve diğer kimlik doğrulama yöntemlerini yürütmek.
2. Kullanıcı rolüne göre bayi, mühendis, satış, yönetici ve ekip erişimlerini yönetmek.
3. Teknik destek talebi oluşturmak, talebi doğru kişiye/gruba atamak, SLA ve eskalasyon süreçlerini takip etmek.
4. Teknik destek mesajlaşmasını, grup iletişimini, topluluk paylaşımını ve AI destekli teknik soru-cevap hizmetini sağlamak.
5. Randevu, bayi ziyareti, bakım, devreye alma ve saha raporu süreçlerini yürütmek.
6. Ürün, model, seri numarası, ölçüm, arıza, yedek parça ve maliyet bilgilerinin teknik iş akışında kullanılmasını sağlamak.
7. Teklif taleplerini, proje ve müşteri bilgilerini, ürün kalemlerini ve teklif hesaplamalarını yönetmek.
8. Doküman, eğitim, sertifika, BOM/envanter, teknik bilgi hafızası ve ilgili içerik hizmetlerini sunmak.
9. Kullanıcıya uygulama içi ve push bildirim göndermek; duyuru, mesaj, randevu, sertifika ve eğitim hatırlatmalarını yönetmek.
10. Hizmetin güvenliğini, sürekliliğini, performansını ve teknik hata ayıklamasını sağlamak.
11. Kötüye kullanımı, yetkisiz erişimi, sahte hesabı ve güvenlik ihlalini önlemek; gerekli denetim kayıtlarını tutmak.
12. Yasal yükümlülükleri yerine getirmek, hakkın tesisi/kullanılması/korunması için gerekli kayıtları muhafaza etmek ve yetkili makam taleplerini karşılamak.

## 5. Kişisel verilerin toplanma yöntemleri

Veriler; Uygulama ve backend API üzerinden hesap oluşturma, Google ile giriş, profil güncelleme, teknik destek ve mesaj formları, randevu ve ziyaret kayıtları, teklif ve saha formları, dosya yükleme, bildirim ayarları, topluluk etkileşimleri ve otomatik teknik loglar yoluyla toplanır. Google ile giriş kullanılıyorsa kimlik doğrulaması için Google’dan, bildirim kullanılıyorsa Firebase Cloud Messaging’den teknik bildirim token’ı alınabilir.

## 6. Kişisel verilerin işlenmesinin hukuki sebepleri

Kişisel veriler, somut işleme faaliyetine göre KVKK’nın 5. maddesinde öngörülen; kanunlarda açıkça öngörülme, sözleşmenin kurulması veya ifası için gerekli olma, veri sorumlusunun hukuki yükümlülüğünü yerine getirmesi, ilgili kişinin kendisi tarafından alenileştirilmiş olma, bir hakkın tesisi/kullanılması/korunması için zorunlu olma, veri sorumlusunun meşru menfaati ve gerekli olduğu hâllerde açık rıza hukuki sebeplerine dayanılarak işlenir.

Örneğin hesabın çalışması ve teknik destek talebinin yürütülmesi için gerekli hesap ve iş verileri sözleşmesel hizmet ve meşru menfaat kapsamında; vergi/ticari kayıtlar ilgili yasal yükümlülük kapsamında; güvenlik ve denetim kayıtları hizmet güvenliği, hukuki yükümlülük veya hakkın korunması kapsamında; yalnızca açık rızaya dayanan isteğe bağlı özellikler ise açık rıza kapsamında işlenebilir. Somut faaliyet için açık rıza gerekmiyorsa hizmetin tamamı açık rıza şartına bağlanmaz.

## 7. Kişisel verilerin aktarılması

Kişisel veriler, amaçla sınırlı ve gerekli ölçüde aşağıdaki alıcı gruplarına aktarılabilir:

| Alıcı grubu | Aktarım amacı |
|---|---|
| Yetkili ENTPA çalışanları ve yöneticileri | Teknik destek, bayi yönetimi, satış, mühendislik, saha, denetim ve operasyon |
| Yetkili bayi, mühendis ve satış kullanıcıları | İlgili destek, randevu, ziyaret, teklif veya iletişim işinin yürütülmesi |
| Supabase/PostgreSQL ve Render hizmetleri | Veritabanı, API barındırma ve teknik operasyon |
| Firebase hizmetleri | Google ile giriş veya push bildirimleri etkinse kimlik doğrulama/bildirim |
| S3 uyumlu depolama hizmeti | Dosya, fotoğraf, imza, doküman ve sertifika eklerinin saklanması |
| AI/RAG hizmet sağlayıcıları | Bu özellik production’da etkinse teknik soru, belge metni veya embedding işlemleri |
| Yetkili kamu kurumları ve adli makamlar | Kanuni yükümlülük veya hukuki talep |

Yurt dışına aktarım söz konusuysa aktarım, KVKK’nın güncel hükümlerine uygun yeterlilik kararı, uygun güvence, standart sözleşme veya diğer uygulanabilir aktarım mekanizmaları üzerinden ve gerekli şartlar sağlanarak yapılır. Gerçek production sağlayıcıları ve aktarım ülkeleri yayımdan önce kesinleştirilmelidir.

## 8. Saklama süresi ve imha

Kişisel veriler, işleme amacının gerektirdiği süre ve ilgili mevzuatın öngördüğü yasal süreyle sınırlı olarak saklanır. Kullanıcı hesabı ve profil verileri hesap veya yetkilendirilmiş bayi ilişkisi devam ettiği sürece; destek, randevu, ziyaret, bakım, devreye alma, teklif, yedek parça ve saha kayıtları ilgili iş ilişkisi, uyuşmazlık veya yasal yükümlülük devam ettiği sürece tutulabilir.

Vergi ve ticari kayıtlar, ilgili vergi ve ticaret mevzuatındaki sürelerden daha kısa olmayacak şekilde saklanır. Bildirim token’ı geçerliliğini yitirdiğinde veya kullanıcı bildirimleri kapattığında silinir ya da güncellenir. Teknik loglar, dosyalar ve yedekler güvenlik, hizmet sürekliliği ve yasal gereklilikler için gerekli asgari süreyle sınırlı tutulur.

İşleme amacı veya yasal saklama sebebi ortadan kalktığında veriler, ENTPA’nın saklama ve imha prosedürüne göre silinir, yok edilir veya anonimleştirilir. Devam eden uyuşmazlık, denetim veya hukuki hakların korunması için gerekli kayıtlar süreç tamamlanıncaya kadar tutulabilir.

## 9. Veri güvenliği

ENTPA; yetkisiz erişim, veri kaybı, değiştirme ve açıklamayı önlemek için HTTPS/TLS, rol tabanlı yetkilendirme, güvenli oturum yönetimi, parola özeti, secret yönetimi, erişim kısıtları, teknik loglama ve yedekleme gibi teknik ve idari tedbirler uygular. Dosya erişimi yetki kontrolü ve mümkün olduğunda süreli/imzalı bağlantılarla sınırlandırılır.

Kullanıcılar parolalarını ve doğrulama bilgilerini paylaşmamalı, Uygulama’ya gereksiz kişisel veya özel nitelikli veri yüklememelidir. Bir veri güvenliği olayı tespit edilirse yürürlükteki mevzuata uygun müdahale ve bildirim süreçleri uygulanır.

## 10. İlgili kişinin hakları

KVKK’nın 11. maddesi kapsamında ilgili kişi; kişisel verilerinin işlenip işlenmediğini öğrenme, işlenmişse buna ilişkin bilgi talep etme, işleme amacını ve amaca uygun kullanılıp kullanılmadığını öğrenme, aktarım yapılan üçüncü kişileri bilme, eksik veya yanlış verilerin düzeltilmesini isteme, şartları oluştuğunda verilerin silinmesini veya yok edilmesini isteme, düzeltme/silme işlemlerinin aktarılan üçüncü kişilere bildirilmesini isteme, işlenen verilerin münhasıran otomatik sistemler yoluyla analiz edilmesi sonucunda aleyhe bir sonucun ortaya çıkmasına itiraz etme ve kanuna aykırı işleme nedeniyle zararın giderilmesini talep etme haklarına sahiptir.

Başvurular, kimlik doğrulaması yapılabilecek şekilde **ekerim@entpa.com.tr** adresine iletilebilir. Başvuruda talep konusu ve güvenli geri dönüş yöntemi belirtilmelidir. ENTPA, başvuruyu sonuçlandırmak için gerekli kimlik doğrulama bilgilerini isteyebilir ve başvuruları KVKK ile ilgili ikincil mevzuattaki usul ve süreler çerçevesinde sonuçlandırır.

## 11. Hesap kapatma ve veri silme talebi

Kullanıcı, hesabının kapatılması ve kişisel verilerinin silinmesi/anonimleştirilmesi için **ekerim@entpa.com.tr** adresine başvurabilir. Talep, yasal olarak saklanması zorunlu kayıtlar, devam eden uyuşmazlık kayıtları ve anonimleştirilmiş veriler saklı kalmak üzere değerlendirilir. Ana sistemden silinen veriler, teknik yedekleme döngüsü nedeniyle yedeklerde kısa bir süre daha kalabilir ve ardından üzerine yazılır.

## 12. Çocukların verileri

Uygulama, kurumsal bayi, mühendis, satış ve saha kullanıcılarına yönelik olup çocuklara yönelik değildir. ENTPA bilerek çocuklardan kişisel veri toplamaz. Yanlışlıkla bir çocuğa ait veri işlendiği düşünülüyorsa ekerim@entpa.com.tr adresine bildirim yapılmalıdır.

## 13. Güncellemeler

Bu Aydınlatma Metni; uygulama özellikleri, veri akışları, hizmet sağlayıcıları veya mevzuat değişiklikleri nedeniyle güncellenebilir. Güncel metin yayımlandığında “Son güncelleme” tarihi değiştirilir. Önemli değişiklikler uygun iletişim kanallarıyla ayrıca duyurulabilir.

## 14. İletişim

**ENTPA Elektronik Cihazlar Tic. Paz. ve Turizm A.Ş.**  
Y. Dudullu OSB. 1. Cadde No: 23, 34775 Ümraniye – İstanbul / TR  
**E-posta:** ekerim@entpa.com.tr

### Kaynaklar

[1]: https://www.kvkk.gov.tr/Icerik/2038/kisisel-verilerin-silinmesi-yok-edilmesi-veya-anonim-hale-getirilmesi KVKK — Kişisel verilerin silinmesi, yok edilmesi veya anonim hâle getirilmesi
[2]: https://www.kvkk.gov.tr/Icerik/5441/KISISEL-VERILERIN-SILINMESI-YOK-EDILMESI-VEYA-ANONIM-HALE-GETIRILMESI-HAKKINDA-YONETMELIK KVKK — Saklama ve imha yönetmeliği
[3]: https://www.kvkk.gov.tr/ KVKK — Kişisel Verileri Koruma Kurumu
