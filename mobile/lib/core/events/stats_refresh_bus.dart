import 'package:flutter/foundation.dart';

/// Kullanıcı isteği: "istatistik kartları anlık güncellenmiyor" — AI
/// Teknik Asistan sekmesi (Hızlı İşlemler'den değil, ayrı bir alt/üst
/// menü sekmesinden açıldığı için "dönünce yenile" mantığının hiç
/// kapsamadığı bir yer) her başarılı soru-cevabından sonra bunu
/// "dürtüyor" (bump), Ana Sayfa da bu sinyali dinleyip "BU AY"
/// istatistiklerini yeniden çekiyor.
class StatsRefreshBus {
  StatsRefreshBus._();
  static final ValueNotifier<int> _trigger = ValueNotifier(0);
  static ValueNotifier<int> get trigger => _trigger;

  static void bump() => _trigger.value++;
}
