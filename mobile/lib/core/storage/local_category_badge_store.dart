import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcı isteği: "dosya indirdiğimde İndirilenlerim kartında rozet
/// olmalı, tıklayınca kapanmalı" — indirme tamamen yerel (cihaz içi) bir
/// işlem olduğu için backend'de bir "okunmadı bildirimi" kaydı yok. Bu
/// sınıf, sadece cihazda tutulan basit bir sayaç ile aynı "rozet göster /
/// açılınca kapat" davranışını, backend'e ihtiyaç duymadan sağlıyor.
class LocalCategoryBadgeStore {
  static final LocalCategoryBadgeStore _instance = LocalCategoryBadgeStore._internal();
  factory LocalCategoryBadgeStore() => _instance;
  LocalCategoryBadgeStore._internal();

  static const _prefix = 'local_badge_';

  /// Ana Sayfa'nın bu sinyali dinleyip Hızlı İşlemler rozetlerini
  /// yeniden çekmesi/birleştirmesi için.
  final ValueNotifier<int> trigger = ValueNotifier(0);

  Future<void> increment(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('$_prefix$category') ?? 0;
    await prefs.setInt('$_prefix$category', current + 1);
    trigger.value++;
  }

  Future<void> clear(String category) async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getInt('$_prefix$category') ?? 0) == 0) return;
    await prefs.setInt('$_prefix$category', 0);
    trigger.value++;
  }

  Future<int> get(String category) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefix$category') ?? 0;
  }
}
