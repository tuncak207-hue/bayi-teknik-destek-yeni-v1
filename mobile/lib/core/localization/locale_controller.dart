import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcı isteği: "İngilizce dil desteği ekle" — ThemeController ile
/// aynı desende: app.dart bunu dinleyip MaterialApp.router'ın `locale`
/// ayarını günceller, Profil'deki dil seçimi bunu değiştirip cihazda
/// kalıcı olarak saklar.
class LocaleController {
  static final LocaleController _instance = LocaleController._internal();
  factory LocaleController() => _instance;
  LocaleController._internal();

  static const _prefsKey = 'app_locale_code';

  /// null = cihazın sistem dilini kullan (desteklenmiyorsa Türkçe'ye düşer).
  final ValueNotifier<Locale?> locale = ValueNotifier(null);

  Future<void> loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && saved.isNotEmpty) {
        locale.value = Locale(saved);
      }
    } catch (_) {}
  }

  Future<void> setLocale(String? languageCode) async {
    locale.value = languageCode == null ? null : Locale(languageCode);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (languageCode == null) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, languageCode);
      }
    } catch (_) {}
  }
}
