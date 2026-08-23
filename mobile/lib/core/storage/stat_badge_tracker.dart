import 'package:shared_preferences/shared_preferences.dart';

/// Ana Sayfa'daki istatistik kartlarında "yeni bir şey oldu" rozeti
/// göstermek için, her sayının en son ne zaman görüldüğünü yerel olarak
/// (cihazda) saklar. Sunucudan gelen sayı, son görülenden büyükse rozet
/// gösterilir; kullanıcı o karta girip baktığında yeni değer "görüldü"
/// olarak kaydedilir ve rozet kaybolur.
class StatBadgeTracker {
  static const _prefix = 'stat_badge_seen_';

  Future<bool> hasNewValue(String key, int currentValue) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getInt('$_prefix$key') ?? 0;
    return currentValue > seen;
  }

  Future<void> markSeen(String key, int currentValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix$key', currentValue);
  }
}
