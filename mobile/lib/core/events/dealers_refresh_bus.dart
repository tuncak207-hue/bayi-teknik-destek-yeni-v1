import 'package:flutter/foundation.dart';

/// Bayiler listesi, alt menüde sürekli açık kalan bir sekme olduğu için,
/// Engellenenler ekranından bir bayinin engeli kaldırıldığında (ya da
/// başka bir yerden bir bayi engellendiğinde) otomatik yenilenmiyordu —
/// kullanıcı elle "aşağı çekip yenile" yapmadıkça değişiklik görünmüyordu.
///
/// Bu, tam bir state-management kütüphanesi gerektirmeyecek kadar basit
/// bir ihtiyaç: sadece "bayi listesi bayatladı, yenile" sinyali yeterli.
/// `bump()` her çağrıldığında sayaç artar, `DealersScreen` bu değeri
/// dinleyip kendini otomatik yeniler.
class DealersRefreshBus {
  DealersRefreshBus._();
  static final ValueNotifier<int> _trigger = ValueNotifier(0);
  static ValueNotifier<int> get trigger => _trigger;

  static void bump() => _trigger.value++;
}
