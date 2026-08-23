import 'package:flutter/material.dart';

/// KVKK Aydınlatma Metni (Kişisel Verilerin Korunması Kanunu — 6698 sayılı Kanun)
///
/// ÖNEMLİ: Bu metin ŞABLON/TASLAK niteliğindedir. Gerçek yayın öncesi:
/// 1. Köşeli parantez [ ] içindeki tüm alanlar gerçek bilgilerle doldurulmalı,
/// 2. Uygulamanın gerçekte topladığı/işlediği veriler ile metin birebir
///    eşleştirilmeli (örn. Firebase/FCM, Supabase, R2 gibi üçüncü taraf
///    veri işleyicileri varsa bunlar açıkça belirtilmeli),
/// 3. Bir hukuk danışmanı tarafından incelenip onaylanmalıdır.
/// Bu metin hukuki tavsiye niteliği taşımaz.
class KvkkScreen extends StatelessWidget {
  const KvkkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KVKK Aydınlatma Metni')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _Heading('1. Veri Sorumlusu'),
          _Body(
            '6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") uyarınca, '
            'kişisel verileriniz veri sorumlusu sıfatıyla [ŞİRKET TİCARET UNVANI] '
            '("Şirket") tarafından aşağıda açıklanan kapsamda işlenmektedir.\n\n'
            'Adres: [ŞİRKET ADRESİ]\n'
            'E-posta: [kvkk@sirket.com]\n'
            'Mersis No: [MERSİS NUMARASI]',
          ),
          SizedBox(height: 20),
          _Heading('2. İşlenen Kişisel Veriler'),
          _Body(
            'Bayi Teknik Destek uygulamasını kullanımınız sırasında aşağıdaki '
            'kişisel verileriniz işlenebilir:\n\n'
            '• Kimlik Bilgileri: Ad, soyad\n'
            '• İletişim Bilgileri: E-posta adresi, telefon numarası\n'
            '• Mesleki Bilgiler: Firma adı\n'
            '• Kullanıcı İşlem Bilgileri: Uygulama içi mesajlaşma içerikleri, '
            'sorulan teknik sorular, yüklenen fotoğraflar\n'
            '• Teknik Veriler: Cihaz push bildirim kimliği (FCM token), IP adresi, '
            'oturum/erişim kayıtları\n'
            '• Görsel Kayıtlar: Profil fotoğrafı, teknik sorun fotoğrafları (varsa)',
          ),
          SizedBox(height: 20),
          _Heading('3. Kişisel Verilerin İşlenme Amaçları'),
          _Body(
            'Kişisel verileriniz;\n\n'
            '• Bayi hesabının oluşturulması ve doğrulanması,\n'
            '• Yapay zeka destekli teknik destek hizmetinin sunulması,\n'
            '• Bayiler arası iletişimin (mesajlaşma) sağlanması,\n'
            '• Push bildirimlerinin gönderilmesi,\n'
            '• Hizmet kalitesinin izlenmesi ve geliştirilmesi,\n'
            '• Yasal yükümlülüklerin yerine getirilmesi\n\n'
            'amaçlarıyla işlenmektedir.',
          ),
          SizedBox(height: 20),
          _Heading('4. Kişisel Verilerin Aktarılması'),
          _Body(
            'Kişisel verileriniz, yukarıda belirtilen amaçların gerçekleştirilmesi '
            'ile sınırlı olarak aşağıdaki taraflara aktarılabilir:\n\n'
            '• Bulut altyapı ve veri depolama hizmeti sağlayıcılarına '
            '(örn. veritabanı ve dosya depolama hizmeti sağlayıcıları),\n'
            '• Push bildirim altyapı sağlayıcısına (Firebase Cloud Messaging — Google),\n'
            '• Yapay zeka destekli yanıt üretimi için kullanılan yapay zeka '
            'servis sağlayıcısına (yalnızca sorduğunuz teknik soru içeriği ile sınırlı olarak),\n'
            '• Yetkili kamu kurum ve kuruluşlarına (yasal zorunluluk hâlinde).\n\n'
            'Bu aktarımlar KVKK\'nın 8. ve 9. maddelerinde belirtilen şartlara '
            'uygun şekilde gerçekleştirilir.',
          ),
          SizedBox(height: 20),
          _Heading('5. Kişisel Veri Toplamanın Yöntemi ve Hukuki Sebebi'),
          _Body(
            'Kişisel verileriniz, mobil uygulama üzerinden elektronik ortamda, '
            'kayıt formu doldurmanız, uygulamayı kullanmanız ve mesajlaşmanız '
            'yoluyla toplanmakta olup; KVKK\'nın 5. maddesinde belirtilen '
            '"sözleşmenin kurulması veya ifasıyla doğrudan doğruya ilgili olması", '
            '"veri sorumlusunun meşru menfaati" ve açık rızanızın bulunduğu hâllerde '
            '"açık rıza" hukuki sebeplerine dayanılarak işlenmektedir.',
          ),
          SizedBox(height: 20),
          _Heading('6. KVKK Kapsamındaki Haklarınız'),
          _Body(
            'KVKK\'nın 11. maddesi uyarınca aşağıdaki haklara sahipsiniz:\n\n'
            '• Kişisel verilerinizin işlenip işlenmediğini öğrenme,\n'
            '• İşlenmişse buna ilişkin bilgi talep etme,\n'
            '• İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme,\n'
            '• Yurt içinde/dışında aktarıldığı üçüncü kişileri bilme,\n'
            '• Eksik veya yanlış işlenmişse düzeltilmesini isteme,\n'
            '• KVKK\'nın 7. maddesindeki şartlar çerçevesinde silinmesini/yok '
            'edilmesini isteme,\n'
            '• Yapılan işlemlerin, verilerin aktarıldığı üçüncü kişilere '
            'bildirilmesini isteme,\n'
            '• Otomatik sistemlerle analiz edilmesi suretiyle aleyhinize bir '
            'sonucun ortaya çıkmasına itiraz etme,\n'
            '• Kanuna aykırı işlenmesi sebebiyle zarara uğramanız hâlinde '
            'zararın giderilmesini talep etme.',
          ),
          SizedBox(height: 20),
          _Heading('7. Başvuru Yöntemi'),
          _Body(
            'Yukarıdaki haklarınızı kullanmak için taleplerinizi '
            '[kvkk@sirket.com] adresine e-posta yoluyla veya [ŞİRKET ADRESİ] '
            'adresine yazılı olarak iletebilirsiniz.',
          ),
          SizedBox(height: 32),
          _NoticeBox(),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700));
  }
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.5)),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: const Text(
        'Bu metin taslak niteliğindedir, hukuki tavsiye değildir. Yayın öncesi '
        'köşeli parantez içindeki bilgiler doldurulmalı ve bir hukuk danışmanı '
        'tarafından incelenmelidir.',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
    );
  }
}
