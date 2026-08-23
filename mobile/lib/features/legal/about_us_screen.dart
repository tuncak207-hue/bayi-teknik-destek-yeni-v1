import 'package:flutter/material.dart';

/// NOT: Buradaki içerik ŞABLON metindir. Yayına çıkmadan önce köşeli
/// parantez [ ] içindeki tüm alanlar gerçek şirket bilgileriyle
/// doldurulmalıdır.
class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hakkımızda')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionTitle('Bayi Teknik Destek'),
          const SizedBox(height: 8),
          const Text(
            '[ŞİRKET UNVANI] tarafından geliştirilen Bayi Teknik Destek uygulaması, '
            'yangın alarm ve güvenlik kamera sistemleri bayilerine, yapay zeka '
            'destekli teknik doküman arama ve bayiler arası iletişim hizmeti sunar.',
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Şirket Bilgileri'),
          const SizedBox(height: 8),
          const _InfoRow(label: 'Ticaret Unvanı', value: '[ŞİRKET TİCARET UNVANI]'),
          const _InfoRow(label: 'Adres', value: '[ŞİRKET ADRESİ]'),
          const _InfoRow(label: 'Mersis No', value: '[MERSİS NUMARASI]'),
          const _InfoRow(label: 'Vergi Dairesi / No', value: '[VERGİ DAİRESİ] / [VERGİ NUMARASI]'),
          const _InfoRow(label: 'E-posta', value: '[iletisim@sirket.com]'),
          const _InfoRow(label: 'Telefon', value: '[+90 XXX XXX XX XX]'),
          const SizedBox(height: 24),
          const _SectionTitle('Sürüm Bilgisi'),
          const SizedBox(height: 8),
          const Text('Uygulama Sürümü: 0.1.0'),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Text(
              'Bu ekrandaki bilgiler geliştirme aşamasında yer tutucu (placeholder) '
              'olarak eklenmiştir. Yayın öncesi gerçek şirket bilgileriyle güncellenmelidir.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
