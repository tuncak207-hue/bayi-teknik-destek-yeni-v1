import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ÖNEMLİ: "Status Bar gri, Navigation Bar siyah" sorununun bir parçası
  // da, uygulamanın modern Android edge-to-edge modunu AÇIKÇA
  // etkinleştirmemesiydi. Bu satır, sistem çubuklarının arkasına içerik
  // çizilmesine (ve app.dart'taki AnnotatedRegion'ın renklerini doğru
  // uygulamasına) izin veriyor — güncel Flutter/Android'in beklediği
  // standart yaklaşım.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // google-services.json (Android) / GoogleService-Info.plist (iOS) projeye
  // eklenmemişse bu çağrı hata fırlatır; push olmadan da uygulamanın açılmaya
  // devam etmesi için yakalayıp yutuyoruz (bkz. README "Firebase Kurulumu").
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // ignore: avoid_print
    print('[firebase] Başlatılamadı (google-services.json eksik olabilir): $e');
  }

  // Kullanıcının daha önce seçtiği yazı boyutu ve parmak izi kilidi
  // tercihlerini yükle.
  await ThemeController().loadFontScale();
  await ThemeController().loadBiometricPreference();

  runApp(const ProviderScope(child: BayiTeknikDestekApp()));
}
