import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../../app/router.dart';
import 'notification_sound_service.dart';

/// Uygulama açıldığında ve giriş yapıldığında çağrılır:
/// 1. Bildirim izni ister
/// 2. FCM token'ı alır
/// 3. Backend'e kaydeder (POST /notifications/register-token)
/// 4. Uygulama açıkken gelen bildirimleri küçük bir sistem bildirimi olarak gösterir
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initAndRegister() async {
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        // Kullanıcı reddetti; sessizce devam et, push olmadan uygulama çalışmaya devam eder.
        return;
      }

      if (!_initialized) {
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidInit);
        await _localNotifications.initialize(initSettings);
        _initialized = true;
      }

      final token = await messaging.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }

      // Token yenilenirse (ör. uygulama yeniden yüklenirse) tekrar backend'e gönder.
      messaging.onTokenRefresh.listen(_sendTokenToBackend);

      // Uygulama ön plandayken gelen bildirimleri kullanıcıya göster.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Ses her zaman çalsın — "en önemli kural: her bildirimde ses"
        NotificationSoundService().play();

        final notification = message.notification;
        if (notification == null) return;

        // Sohbet mesajları (new_message/group_message) için sistem
        // bildirimi GÖSTERME — bu türler zaten uygulama içi anlık
        // güncellemeyle (rozet, sohbet ekranı) yansıyor; hem soket hem
        // push aynı anda "çift bildirim" gösterirdi. Diğer türler
        // (randevu, duyuru vb.) için normal şekilde göster.
        final type = message.data['type'] as String?;
        if (type == 'new_message' || type == 'group_message') return;

        _showLocalNotification(notification.title, notification.body);
      });

      // Uygulama arka plandayken bildirime dokunulup öne getirildiğinde,
      // ilgili ekrana yönlendir (derin bağlantı — bildirim listesindeki
      // tıklama davranışıyla aynı mantık).
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Uygulama tamamen kapalıyken bildirime dokunularak açıldıysa da
      // aynı şekilde yönlendir.
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      // Firebase yapılandırılmamışsa (google-services.json eksikse) burada hata
      // fırlar; push olmadan da uygulamanın çalışmaya devam etmesi için yutuyoruz.
      // ignore: avoid_print
      print('[push] Firebase başlatılamadı veya izin alınamadı: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      final Dio dio = ApiClient().dio;
      await dio.post('/notifications/register-token', data: {'token': token});
    } catch (e) {
      // ignore: avoid_print
      print('[push] Token backend\'e kaydedilemedi: $e');
    }
  }

  /// Çıkış yapılırken çağrılır — önceden bu hiç yapılmıyordu, aynı
  /// cihazda hesap değiştirilirse eski hesap da yeni hesaba gelen
  /// bildirimleri almaya devam edebiliyordu.
  Future<void> unregister() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final Dio dio = ApiClient().dio;
      await dio.post('/notifications/unregister-token', data: {'token': token});
    } catch (e) {
      // ignore: avoid_print
      print('[push] Token kaldırılamadı: $e');
    }
  }

  /// Bildirime dokunulunca ilgili ekrana yönlendirir — uygulama içi bildirim
  /// listesindeki (`NotificationsScreen`) aynı derin bağlantı mantığı.
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;

    switch (type) {
      case 'new_message':
      case 'group_message':
        final conversationId = data['conversationId'];
        if (conversationId != null) appRouter.push('/chat/$conversationId');
        break;
      case 'reply':
        final postId = data['postId'];
        if (postId != null) appRouter.push('/community/$postId');
        break;
      case 'appointment_requested':
      case 'appointment_status_changed':
      case 'appointment_revised':
      case 'appointment_removed':
        appRouter.push('/appointments');
        break;
      case 'ticket_created':
      case 'ticket_status_changed':
      case 'ticket_assigned':
      case 'ticket_escalated':
      case 'emergency_ticket':
        appRouter.push('/support-tickets');
        break;
      default:
        appRouter.push('/notifications');
    }
  }

  Future<void> _showLocalNotification(String? title, String? body) async {
    if (!Platform.isAndroid) return;
    const androidDetails = AndroidNotificationDetails(
      'bayi_teknik_destek_channel',
      'Bildirimler',
      channelDescription: 'Yeni mesaj, duyuru ve onay bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title ?? 'Bayi Teknik Destek',
      body ?? '',
      details,
    );
  }
}
