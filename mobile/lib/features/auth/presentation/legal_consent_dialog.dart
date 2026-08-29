import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<bool> showLegalConsentDialog(BuildContext context) async {
  var kvkkAccepted = false;
  var privacyAccepted = false;

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Yasal metin onayı'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Kayıt olabilmek için aşağıdaki iki metni okuyup ayrı ayrı kabul etmeniz gerekir.'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: kvkkAccepted,
                onChanged: (value) => setState(() => kvkkAccepted = value ?? false),
                title: const Text('KVKK Aydınlatma Metni’ni okudum ve kabul ediyorum.'),
                secondary: IconButton(
                  tooltip: 'KVKK metnini aç',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => dialogContext.push('/kvkk'),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: privacyAccepted,
                onChanged: (value) => setState(() => privacyAccepted = value ?? false),
                title: const Text('Gizlilik Politikası’nı okudum ve kabul ediyorum.'),
                secondary: IconButton(
                  tooltip: 'Gizlilik Politikasını aç',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => dialogContext.push('/privacy-policy'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: kvkkAccepted && privacyAccepted
                ? () => Navigator.of(dialogContext).pop(true)
                : null,
            child: const Text('Kabul et ve devam et'),
          ),
        ],
      ),
    ),
  );

  return accepted == true;
}
