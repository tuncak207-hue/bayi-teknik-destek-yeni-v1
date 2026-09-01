import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app.dart';
import 'core/theme/theme_controller.dart';
import 'core/localization/locale_controller.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Kullanıcı isteği: "uygulama kapalı olduğunda bir bildirim geldiğinde
/// uygulama kapalıda olsa bildirim gelmeli" — FCM, uygulama tamamen
/// kapalıyken/arka plandayken gelen mesajları bu TOP-LEVEL (main
/// fonksiyonu dışında, sınıfsız) fonksiyona yönlendirir. Backend zaten
/// standart "notification" paketiyle gönderdiği için OS bunu genelde
/// otomatik gösterir; bu işleyici ek bir güvence katmanı ve gelecekte
/// (örn. rozet sayısı güncelleme gibi) ek işlem eklenebilecek bir yer.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Bu noktada widget ağacı yok, sadece Firebase'e erişim var.
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android edge-to-edge görünümünü ilk frame'den önce hazırla.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Kritik olmayan servisleri runApp öncesinde bekletme. Firebase veya yerel
  // tercihlerin yüklenmesi gecikse bile kullanıcı ilk frame'i görebilmelidir.
  final isRelease = bool.fromEnvironment('dart.vm.product');
  runApp(const ProviderScope(child: BayiTeknikDestekApp()));
  unawaited(_initializeServices(isRelease));
}

Future<void> _initializeServices(bool isRelease) async {
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (error, stackTrace) {
    if (isRelease) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError(
            'Firebase release yapılandırması başlatılamadı. Android için google-services.json, iOS için GoogleService-Info.plist ve APNs ayarlarını kontrol edin.',
          ),
          stack: stackTrace,
          informationCollector: () sync* {
            yield DiagnosticsProperty<Object?>('originalError', error);
          },
        ),
      );
    } else {
      debugPrint('[firebase] Debug yapılandırması başlatılamadı: $error');
    }
  }

  try {
    final themeController = ThemeController();
    await themeController.loadFontScale();
    await themeController.loadBiometricPreference();
    // Kullanıcı isteği: "İngilizce dil desteği ekle" — daha önce
    // seçilmiş bir dil varsa uygulama onu kullanır.
    await LocaleController().loadSaved();
  } catch (error, stackTrace) {
    debugPrint('[preferences] Başlangıç tercihleri yüklenemedi: $error');
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stackTrace),
    );
  }
}
