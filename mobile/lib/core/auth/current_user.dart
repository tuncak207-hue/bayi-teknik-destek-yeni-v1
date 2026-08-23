import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../theme/theme_controller.dart';

/// Giriş yapan bayinin kimlik bilgisini (id, ad soyad) uygulama boyunca
/// hafızada tutan basit bir "oturum" tutucusu. Mesajlaşma ekranlarında
/// "bu mesaj bana mı ait?" karşılaştırması için kullanılır.
class CurrentUser {
  static final CurrentUser _instance = CurrentUser._internal();
  factory CurrentUser() => _instance;
  CurrentUser._internal();

  String? id;
  String? firstName;
  String? lastName;
  // Satış danışmanı hesapları, kendi Mesajlar sekmelerinde normal bayi
  // sohbetleri gibi davranış görmeli (filtre uygulanmamalı) — bu yüzden
  // rolü de hafızada tutuyoruz.
  String? role;

  bool get isLoaded => id != null;

  /// Giriş başarılı olduktan sonra (veya uygulama açılışında token hâlâ
  /// geçerliyse) çağrılır. Backend'den kendi profilini çekip hafızaya alır,
  /// ayrıca kayıtlı karanlık tema tercihini uygulamaya uygular.
  Future<void> load() async {
    try {
      final Dio dio = ApiClient().dio;
      final res = await dio.get('/users/me');
      id = res.data['id'];
      firstName = res.data['firstName'];
      lastName = res.data['lastName'];
      role = res.data['role'];
      ThemeController().setDark(res.data['darkMode'] == true);
    } catch (e) {
      // ignore: avoid_print
      print('[current_user] Profil bilgisi alınamadı: $e');
    }
  }

  void clear() {
    id = null;
    firstName = null;
    lastName = null;
    role = null;
  }
}
