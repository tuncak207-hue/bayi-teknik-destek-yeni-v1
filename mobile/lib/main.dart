import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app.dart';
import 'core/theme/theme_controller.dart';

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
  } catch (error, stackTrace) {
    debugPrint('[preferences] Başlangıç tercihleri yüklenemedi: $error');
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stackTrace),
    );
  }
}
