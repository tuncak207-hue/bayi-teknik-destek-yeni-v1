import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/widgets/design_system.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppPageHeader(title: AppLocalizations.of(context)!.screenPrivacyPolicy),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _Title('ENTPA Bayi Teknik Destek Uygulaması'),
          _Text('Son güncelleme: [Yayın tarihini yazın]\n\nBu metin, uygulamanın gerçek özellikleri esas alınarak hazırlanmış çalışma metnidir. Yayın öncesinde ENTPA’nın hukuk veya KVKK sorumlusu tarafından onaylanmalıdır.'),
          _Title('1. Veri sorumlusu'),
          _Text('ENTPA Elektronik Cihazlar Tic. Paz. ve Turizm A.Ş.\nY. Dudullu OSB. 1. Cadde No: 23, 34775 Ümraniye – İstanbul / TR\nGizlilik ve destek: ekerim@entpa.com.tr'),
          _Title('2. Hangi verileri işleriz?'),
          _Text('Hesap için ad, soyad, şirket, telefon, e-posta, Google hesap kimliği, rol ve profil bilgileri; teknik destek için ürün, model, seri numarası, lokasyon, açıklama, fotoğraf/video, ölçüm, parça ve saha kayıtları; randevu, ziyaret, bakım, devreye alma ve teklif süreçleri için ilgili tarih, il/ilçe, müşteri/iletişim kişisi ve iş bilgileri işlenebilir. Mesajlar, topluluk gönderileri, yorumlar, dokümanlar, sertifikalar, müşteri imzaları, favoriler, bildirim tercihleri ve Firebase bildirim token’ı da ilgili özellik kullanıldığında işlenebilir.'),
          _Title('3. Kullanım amaçları'),
          _Text('Veriler; hesabı doğrulamak ve yönetmek, teknik destek ve mesajlaşma hizmetini sunmak, randevu ve saha operasyonlarını yürütmek, doküman/eğitim/sertifika hizmetlerini sağlamak, teklif ve yedek parça süreçlerini takip etmek, bildirim göndermek, güvenliği sağlamak ve yasal yükümlülükleri yerine getirmek için kullanılır. AI/RAG özelliği etkinse teknik sorular ve ilgili içerikler yanıt üretmek için işlenebilir.'),
          _Title('4. Hizmet sağlayıcılar'),
          _Text('Uygulama; veritabanı ve barındırma için Supabase ve Render, giriş/bildirim için Firebase, dosyalar için S3 uyumlu depolama ve AI/RAG etkinse ilgili AI sağlayıcılarını kullanabilir. Gerçek sağlayıcılar ve yurt dışı aktarım şartları yayın öncesinde doğrulanmalıdır.'),
          _Title('5. Saklama ve güvenlik'),
          _Text('Veriler, işleme amacının gerektirdiği ve ilgili mevzuatın öngördüğü süre boyunca saklanır. Amaç veya yasal saklama sebebi ortadan kalktığında silinir, yok edilir veya anonimleştirilir. HTTPS/TLS, rol tabanlı erişim, güvenli oturum, parola özeti ve erişim kontrolleri gibi tedbirler uygulanır.'),
          _Title('6. Haklarınız'),
          _Text('Kişisel verilerinizle ilgili erişim, düzeltme, silme/yok etme ve diğer KVKK haklarınız için ekerim@entpa.com.tr adresine başvurabilirsiniz. Hesap silme talebinizi de aynı adrese iletebilirsiniz.'),
          _Title('7. İletişim'),
          _Text('ENTPA Elektronik Cihazlar Tic. Paz. ve Turizm A.Ş.\nY. Dudullu OSB. 1. Cadde No: 23, 34775 Ümraniye – İstanbul / TR\nekerim@entpa.com.tr'),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
}

class _Text extends StatelessWidget {
  final String text;
  const _Text(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 13.5, height: 1.5));
}
