import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

Future<bool> showLegalConsentDialog(BuildContext context) async {
  var kvkkAccepted = false;
  var privacyAccepted = false;

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.legalConsentTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context)!.legalConsentHint),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: kvkkAccepted,
                onChanged: (value) => setState(() => kvkkAccepted = value ?? false),
                title: Text(AppLocalizations.of(context)!.kvkkAgree),
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
                title: Text(AppLocalizations.of(context)!.privacyPolicyAgree),
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
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: kvkkAccepted && privacyAccepted
                ? () => Navigator.of(dialogContext).pop(true)
                : null,
            child: Text(AppLocalizations.of(context)!.acceptAndContinue),
          ),
        ],
      ),
    ),
  );

  return accepted == true;
}
