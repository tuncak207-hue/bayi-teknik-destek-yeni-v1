import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

/// Kullanıcı Ana Sayfa'ya her geldiğinde (girişte veya splash'ten sonra)
/// çağrılır. Henüz onaylanmamış kritik duyuru varsa, kapatılamayan bir
/// dialog gösterir — "Okudum, Anladım" demeden geçilemez.
class CriticalAnnouncementGate {
  static Future<void> checkAndShow(BuildContext context) async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get('/announcements/unacknowledged-critical');
      final announcements = res.data as List;
      for (final a in announcements) {
        if (!context.mounted) return;
        await _showBlockingDialog(context, a);
      }
    } catch (_) {
      // Bağlantı sorununda uygulamayı kilitleme, sessizce geç.
    }
  }

  static Future<void> _showBlockingDialog(BuildContext context, dynamic announcement) async {
    final dio = ApiClient().dio;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.brand, size: 26),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(AppLocalizations.of(context)!.criticalAnnouncement, style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  announcement['title'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                ),
                const SizedBox(height: 8),
                Text(announcement['body'] ?? ''),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await dio.post('/announcements/${announcement['id']}/acknowledge');
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: Text(AppLocalizations.of(context)!.readUnderstood),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
