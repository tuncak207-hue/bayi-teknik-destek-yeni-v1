import 'package:flutter/foundation.dart';

/// Herhangi bir bildirim (randevu, eğitim içeriği, sertifika uyarısı vb.)
/// anlık geldiğinde, hangi ekranda olursanız olun Ana Sayfa'daki kart
/// rozetlerinin tazelenmesi için — `RootShell` her zaman açık olduğu için
/// soket bildirimini oradan dinleyip burayı "dürtüyor" (bump), Ana Sayfa
/// da bu sinyali dinleyip kendi rozet sayılarını yeniden çekiyor.
class NotificationBadgeBus {
  NotificationBadgeBus._();
  static final ValueNotifier<int> _trigger = ValueNotifier(0);
  static ValueNotifier<int> get trigger => _trigger;

  static void bump() => _trigger.value++;
}
