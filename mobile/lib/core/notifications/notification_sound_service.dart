import 'package:audioplayers/audioplayers.dart';

/// Uygulama açıkken (ön planda) yeni bir mesaj/bildirim geldiğinde kısa
/// bir "ding" sesi çalar. Arka plandayken sistem zaten FCM push
/// bildirimlerinin kendi sesini çalıyor — bu servis sadece uygulama
/// AÇIKKEN, push bildiriminin sesi çalınmayan durumlar için var.
class NotificationSoundService {
  static final NotificationSoundService _instance = NotificationSoundService._internal();
  factory NotificationSoundService() => _instance;
  NotificationSoundService._internal();

  /// ÖNEMLİ: Önceden TEK bir AudioPlayer örneği tekrar tekrar kullanılıyordu
  /// — bir çalma sırasında bir şekilde "takılı" bir duruma geçerse (örn.
  /// hızlı art arda bildirimlerde), sonraki tüm çağrılar sessizce
  /// başarısız olabiliyordu. Artık HER çalışta TAMAMEN YENİ bir
  /// AudioPlayer oluşturulup, işi bitince serbest bırakılıyor — bu, önceki
  /// bir çalmanın durumundan hiç etkilenmemesini garanti eder.
  Future<void> play() async {
    final player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.release);
      await player.play(AssetSource('sounds/notification.mp3'));
      // Ses birkaç yüz milisaniye sürüyor — çalması bitmeden player'ı
      // serbest bırakırsak bazı Android sürümlerinde ses kesilebiliyor.
      await Future.delayed(const Duration(milliseconds: 800));
    } catch (e) {
      // ÖNEMLİ: Ses çalınamıyorsa bu satır terminaldeki `flutter run`
      // çıktısında görünür — sorun devam ederse bu satırın tam metnini
      // paylaşmanız kesin sebebi bulmamıza yardımcı olur.
      // ignore: avoid_print
      print('[notification_sound] Çalınamadı: $e');
    } finally {
      await player.dispose();
    }
  }
}
