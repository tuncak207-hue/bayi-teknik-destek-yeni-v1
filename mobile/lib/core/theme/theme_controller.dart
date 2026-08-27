import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama genelinde tema modunu (açık/koyu) ve yazı boyutu ölçeğini tutan
/// basit bir kontrolcü. Profil/Ayarlar ekranındaki ilgili kontroller bunu
/// günceller, `app.dart` bu değerleri dinleyip `MaterialApp.router`'ın
/// `themeMode` ve `textScaler` ayarlarını değiştirir.
class ThemeController {
  static final ThemeController _instance = ThemeController._internal();
  factory ThemeController() => _instance;
  ThemeController._internal();

  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);
  // 1.0 = normal boyut, 1.15 = büyük, 1.3 = çok büyük — sahada güneş
  // altında/uzaktan okurken kullanışlı.
  final ValueNotifier<double> fontScale = ValueNotifier(1.0);

  // Uygulama her açıldığında parmak izi/yüz tanıma sorulsun mu — Ayarlar'dan
  // kullanıcı tercihi. Cihaz bazlı bir tercih olduğu için sunucuya değil,
  // yerel olarak (SharedPreferences) saklanır.
  final ValueNotifier<bool> biometricLockEnabled = ValueNotifier(false);

  Future<void> loadBiometricPreference() async {
    final prefs = await SharedPreferences.getInstance();
    biometricLockEnabled.value =
        prefs.getBool('biometric_lock_enabled') ?? false;
  }

  Future<void> setBiometricLockEnabled(bool value) async {
    biometricLockEnabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_lock_enabled', value);
  }

  Future<void> loadFontScale() async {
    final prefs = await SharedPreferences.getInstance();
    fontScale.value = prefs.getDouble('font_scale') ?? 1.0;
  }

  Future<void> setFontScale(double scale) async {
    fontScale.value = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_scale', scale);
  }

  void setDark(bool isDark) {
    mode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}
