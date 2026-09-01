import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/widgets/design_system.dart';

/// ENTPA Bayi Teknik Destek uygulaması için çalışma taslağıdır.
/// Yayın öncesinde ENTPA'nın hukuk danışmanı tarafından uygulamanın gerçek
/// veri akışları, saklama süreleri ve hizmet sağlayıcılarıyla karşılaştırılarak
/// onaylanmalıdır.
class KvkkScreen extends StatelessWidget {
  const KvkkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppPageHeader(title: AppLocalizations.of(context)!.screenKvkk),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _Heading('Kişisel Verilerin Korunması ve İşlenmesine İlişkin Aydınlatma Metni'),
          _Body(
            'Bu aydınlatma metni, 6698 sayılı Kişisel Verilerin Korunması Kanunu’nun '
            '10. maddesi kapsamında, Bayi Teknik Destek mobil uygulamasının kullanıcılarını '
            'kişisel verilerin işlenmesi hakkında bilgilendirmek amacıyla hazırlanmıştır.',
          ),
          SizedBox(height: 20),
          _Heading('1. Veri Sorumlusu'),
          _Body(
            'Kişisel verileriniz, veri sorumlusu sıfatıyla ENTPA Elektronik Cihazlar '
            'Tic. Paz. ve Turizm A.Ş. tarafından işlenmektedir.\n\n'
'Adres: Y. Dudullu OSB. 1. Cadde No: 23, 34775 Ümraniye – İstanbul / TR\n'
            'E-posta: ekerim@entpa.com.tr',
          ),
          SizedBox(height: 20),
          _Heading('2. İşlenen Kişisel Veriler'),
          _Body(
            'Uygulamayı kullanmanız sırasında, kullanım amacına ve uygulamadaki işlemlerinize '
            'bağlı olarak aşağıdaki veri kategorileri işlenebilir:\n\n'
            '• Kimlik bilgileri: ad ve soyad.\n'
            '• İletişim bilgileri: e-posta adresi ve telefon numarası.\n'
            '• Mesleki bilgiler: bayi/firma bilgisi, görev ve uzmanlık bilgileri.\n'
            '• Kullanıcı işlem bilgileri: teknik sorular, destek kayıtları, randevu ve ziyaret bilgileri.\n'
            '• Görsel ve içerik bilgileri: yüklediğiniz fotoğraflar, belgeler ve mesaj içerikleri.\n'
            '• İşlem güvenliği bilgileri: IP adresi, oturum kayıtları, cihaz ve erişim bilgileri.\n'
            '• Bildirim bilgileri: push bildirimlerinin iletilmesi için gerekli cihaz bildirim belirteci.',
          ),
          SizedBox(height: 20),
          _Heading('3. Kişisel Verilerin İşlenme Amaçları ve Hukuki Sebepleri'),
          _Body(
            'Kişisel verileriniz; kullanıcı hesabının oluşturulması ve yönetilmesi, teknik destek '
            'hizmetlerinin sunulması, yapay zeka destekli teknik yanıtların oluşturulması, bayi '
            'iletişiminin ve mesajlaşma hizmetinin sağlanması, randevu ve ziyaret süreçlerinin '
            'yürütülmesi, bildirimlerin gönderilmesi, uygulama güvenliğinin sağlanması, taleplerin '
            've şikayetlerin cevaplanması ile yasal yükümlülüklerin yerine getirilmesi amaçlarıyla '
            'işlenebilir. İşleme faaliyetleri, somut faaliyete göre KVKK’nın 5. maddesinde belirtilen '
            'kanunlarda açıkça öngörülme, sözleşmenin kurulması veya ifası, veri sorumlusunun hukuki '
            'yükümlülüğü, meşru menfaati ve gerekli hâllerde açık rıza hukuki sebeplerine dayanır.',
          ),
          SizedBox(height: 20),
          _Heading('4. Kişisel Verilerin Aktarılması'),
          _Body(
            'Kişisel verileriniz, yalnızca ilgili hizmetin yürütülmesi için gerekli olduğu ölçüde; '
            'yetkili ENTPA çalışanlarına, bilgi teknolojileri ve barındırma hizmeti sağlayıcılarına, '
            'bildirim ve iletişim altyapısı sağlayıcılarına, yapay zeka hizmet sağlayıcılarına '
            '(teknik soru ve gerekli ek içerik ile sınırlı olarak), hukuken yetkili kamu kurumlarına '
            've profesyonel danışmanlara aktarılabilir. Yurt içi ve yurt dışı aktarımlar, KVKK’nın '
            '8. ve 9. maddelerinde öngörülen şartlara uygun olarak gerçekleştirilir.',
          ),
          SizedBox(height: 20),
          _Heading('5. Kişisel Verilerin Toplanma Yöntemi ve Saklama Süresi'),
          _Body(
            'Verileriniz; uygulamadaki kayıt ve profil formları, destek kayıtları, mesajlaşma, '
            'randevu/ziyaret işlemleri, belge ve fotoğraf yüklemeleri, cihaz bildirim altyapısı ve '
            'uygulama kullanım kayıtları üzerinden elektronik ortamda toplanır. Veriler, ilgili '
            'işleme amacının gerektirdiği süre boyunca ve her hâlde ilgili mevzuattaki zamanaşımı '
            've saklama süreleri kadar muhafaza edilir; süre sonunda silinir, yok edilir veya anonim hâle getirilir.',
          ),
          SizedBox(height: 20),
          _Heading('6. İlgili Kişinin Hakları'),
          _Body(
            'KVKK’nın 11. maddesi uyarınca; kişisel verilerinizin işlenip işlenmediğini öğrenme, '
            'işlenmişse bilgi talep etme, işlenme amacını ve amaca uygun kullanılıp kullanılmadığını '
            'öğrenme, aktarılan üçüncü kişileri bilme, eksik veya yanlış işlenmiş verilerin düzeltilmesini '
            'isteme, kanuni şartlar çerçevesinde silinmesini veya yok edilmesini isteme, yapılan işlemlerin '
            'aktarılmış üçüncü kişilere bildirilmesini isteme, münhasıran otomatik sistemlerle analiz '
            'sonucuna itiraz etme ve kanuna aykırı işleme nedeniyle zararın giderilmesini talep etme haklarına sahipsiniz.',
          ),
          SizedBox(height: 20),
          _Heading('7. Başvuru Yöntemi'),
          _Body(
            'KVKK kapsamındaki taleplerinizi, kimliğinizi doğrulamaya yarayan bilgilerle birlikte '
            'ekerim@entpa.com.tr adresine e-posta yoluyla veya veri sorumlusunun yukarıda belirtilen '
            'adresine yazılı olarak iletebilirsiniz. Başvurular, KVKK ve ilgili ikincil mevzuatta '
            'öngörülen usul ve süreler çerçevesinde sonuçlandırılır.',
          ),
          SizedBox(height: 24),
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
        'Bu metin uygulama veri akışları esas alınarak hazırlanmış çalışma taslağıdır. '
        'Yayın öncesinde ENTPA hukuk danışmanı tarafından incelenip onaylanmalıdır.',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
    );
  }
}
