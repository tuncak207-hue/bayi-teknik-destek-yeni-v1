import 'package:flutter/foundation.dart';

/// Mesajlar sekmesindeki rozet sayısı, önceden sadece kullanıcı o sekmeye
/// bizzat tıklayınca sıfırlanıyordu. Ama bir sohbet başka bir yoldan da
/// (Bildirimler ekranından bir mesaj bildirimine dokunarak) okunmuş
/// olabilir — bu durumda backend'de doğru işaretleniyordu ama alt
/// menüdeki rozet sayısı bunu bilmiyordu. `bump()` her çağrıldığında
/// `RootShell` gerçek sayıyı sunucudan yeniden çeker.
class MessagesBadgeBus {
  MessagesBadgeBus._();
  static final ValueNotifier<int> _trigger = ValueNotifier(0);
  static ValueNotifier<int> get trigger => _trigger;

  static void bump() => _trigger.value++;
}
