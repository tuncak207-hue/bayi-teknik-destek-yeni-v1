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

  final isRelease = bool.fromEnvironment('dart.vm.product');
  try {
    await Firebase.initializeApp();
  } catch (error, stackTrace) {
    if (isRelease) {
      // Release’te Firebase olmadan devam etmek push/auth özelliklerini sessizce
      // bozacağı için yapılandırma hatasını build/runtime health-check olarak açığa çıkar.
      Error.throwWithStackTrace(
        StateError(
          'Firebase release yapılandırması başlatılamadı. Android için google-services.json, iOS için GoogleService-Info.plist ve APNs ayarlarını kontrol edin.',
        ),
        stackTrace,
      );
    }
    debugPrint('[firebase] Debug yapılandırması başlatılamadı: $error');
  }

  // Kullanıcının daha önce seçtiği yazı boyutu ve parmak izi kilidi
  // tercihlerini yükle.
  await ThemeController().loadFontScale();
  await ThemeController().loadBiometricPreference();

  runApp(const ProviderScope(child: BayiTeknikDestekApp()));
}
