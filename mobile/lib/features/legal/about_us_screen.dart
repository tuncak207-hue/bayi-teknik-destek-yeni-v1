import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/widgets/design_system.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppPageHeader(title: AppLocalizations.of(context)!.screenAboutUs),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionTitle('Bayi Teknik Destek'),
          const SizedBox(height: 8),
          const Text(
            'ENTPA Elektronik Cihazlar Tic. Paz. ve Turizm A.Ş. tarafından '
            'geliştirilen Bayi Teknik Destek uygulaması; güvenlik sektöründe '
            'faaliyet gösteren bayilere, yapay zeka destekli teknik doküman '
            'arama ve bayiler arası iletişim hizmeti sunar.',
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Şirket Bilgileri'),
          const SizedBox(height: 8),
          const _InfoRow(label: 'Ticaret Unvanı', value: 'ENTPA Elektronik Cihazlar Tic. Paz. ve Turizm A.Ş.'),
          const _InfoRow(label: 'Adres', value: 'Y. Dudullu OSB, 1. Cadde No:23, 34775 Ümraniye – İstanbul / TR'),
          const _InfoRow(label: 'E-posta', value: 'info@entpa.com.tr'),
          const SizedBox(height: 24),
          const _SectionTitle('Sürüm Bilgisi'),
          const SizedBox(height: 8),
          const Text('Uygulama Sürümü: 0.1.0'),
          const SizedBox(height: 32),
          const Text(
            'ENTPA, 1980 yılından bu yana üstün Türk mühendisliği ve 35 yıllık bilgi '
            'birikimini özgün tasarımlarıyla buluşturan ENTES’in ortakları tarafından '
            '2003 yılında kurulmuştur. Uluslararası ithalatçı ve dağıtıcı kimliğiyle '
            'öne çıkan ENTPA, 2012 yılının ikinci yarısından itibaren güvenlik '
            'sektöründe faaliyet göstermektedir.',
            style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black54),
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
