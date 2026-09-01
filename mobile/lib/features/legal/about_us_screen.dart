import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../core/widgets/design_system.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppPageHeader(title: l10n.screenAboutUs),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionTitle(l10n.dealerTechSupportTitle),
          const SizedBox(height: 8),
          Text(l10n.aboutAppDescription),
          const SizedBox(height: 24),
          _SectionTitle(l10n.companyInfo),
          const SizedBox(height: 8),
          // Kullanıcı isteği: "hukuki/resmi şirket bilgileri" — şirket
          // unvanı, adres ve e-posta bilerek ÇEVRİLMİYOR (resmi tescil
          // bilgisi, dilden bağımsız sabit kalmalı). Sadece etiketler
          // (label) çevriliyor.
          _InfoRow(label: l10n.tradeTitle, value: 'ENTPA Elektronik Cihazlar Tic. Paz. ve Turizm A.Ş.'),
          _InfoRow(label: l10n.addressLabel, value: 'Y. Dudullu OSB, 1. Cadde No:23, 34775 Ümraniye – İstanbul / TR'),
          _InfoRow(label: l10n.emailLabel, value: 'info@entpa.com.tr'),
          const SizedBox(height: 24),
          _SectionTitle(l10n.versionInfo),
          const SizedBox(height: 8),
          Text(l10n.appVersionLabel),
          const SizedBox(height: 32),
          Text(
            l10n.entpaHistory,
            style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black54),
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
