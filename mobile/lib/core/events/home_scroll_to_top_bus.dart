import 'package:flutter/foundation.dart';

/// Kullanıcı isteği: "ana sayfaya bastığımda otomatik en üste dönsün" —
/// alt menüdeki Ana Sayfa sekmesine, zaten Ana Sayfa'dayken tekrar
/// basıldığında bu tetiklenir, Ana Sayfa dinleyip listeyi en üste kaydırır.
class HomeScrollToTopBus {
  static final ValueNotifier<int> trigger = ValueNotifier(0);

  static void fire() => trigger.value++;
}
