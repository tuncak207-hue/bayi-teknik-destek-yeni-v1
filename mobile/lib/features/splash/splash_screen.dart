import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_config.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/auth/token_storage.dart';
import '../../core/auth/current_user.dart';
import '../../core/auth/biometric_service.dart';
import '../../core/api/socket_service.dart';

  /// Açılış ekranı: ENTPA logosu + yangın alarm sesi, kısa süre sonra

/// otomatik olarak giriş ekranına geçer.
///
/// Logo dosyası: assets/images/entpa_logo.png (yoksa yer tutucu ikon gösterilir)
/// Ses dosyası: assets/sounds/fire_alarm.mp3 (yoksa sessiz devam eder, hata vermez)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _logoAvailable = true;

  // Render cold start'ını splash sırasında başlatıyoruz; kullanıcı ana sayfaya
  // geçtiğinde ilk API isteği backend'i yeni uyandırmaya çalışmasın.
  // Kullanıcı isteği: "uygulama geç açılıyor, hemen açılmalı" — önceden
  // 2 saniye sabit bekleme vardı (alarm sesi + logo animasyonu için).
  // Süre kısaltıldı; ses/animasyon hâlâ çalışıyor ama kullanıcıyı
  // gereksiz yere bekletmiyor.
  static const _splashDuration = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _playAlarmSound();
    _warmBackend();
    _scheduleNavigation();
  }

  Future<void> _warmBackend() async {
    // Release sürümünde canlı backend'i splash görünürken uyandırır.
    // Debug sürümünde de yerel/emulator backend için aynı istek zararsızdır.
    final baseUrl = ApiConfig.baseUrl;
    if (baseUrl.trim().isEmpty) return;
    try {
      await Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      )).get('/health');
    } catch (_) {
      // Ana akışı bloklama; HomeScreen kendi retry mekanizmasını kullanır.
    }
  }

  Future<void> _playAlarmSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/fire_alarm.mp3'));
    } catch (e) {
      // Ses dosyası henüz eklenmemişse (bkz. assets/sounds/BURAYA_SES_EKLEYIN.txt)
      // sessizce devam et — açılış akışını bozmasın.
      // ignore: avoid_print
      print('[splash] Alarm sesi çalınamadı (dosya eksik olabilir): $e');
    }
  }

  void _scheduleNavigation() {
    Timer(_splashDuration, () async {
      await _audioPlayer.stop();
      if (!mounted) return;

      // "Beni hatırla" mantığı: token hâlâ kayıtlıysa doğrudan Ana Sayfa'ya
      // geçelim, kullanıcı her uygulama açılışında tekrar giriş yapmasın.
      //
      // ÖNEMLİ: Önceden `getAccessToken()` çağrısı try/catch DIŞINDAYDI —
      // cihazda bozuk/okunamayan şifreli bir depolama girdisi varsa
      // (örn. flutter_secure_storage'ın şifreleme anahtarı bir önceki
      // kurulumdan sonra değiştiyse), bu çağrı yakalanmamış bir istisna
      // fırlatıp splash ekranını SONSUZA KADAR döner halde bırakıyordu —
      // hiçbir zaman /login'e düşmüyordu. Artık bu okuma da güvenli.
      String? token;
      try {
        token = await TokenStorage().getAccessToken();
      } catch (e) {
        // ignore: avoid_print
        print('[splash] Kayıtlı oturum okunamadı (bozuk/eski veri olabilir): $e');
        token = null;
      }
      if (token != null) {
        try {
          await CurrentUser().load();
          await SocketService().connect();

          // Kullanıcı Ayarlar'dan "parmak izi ile açılış kilidi"ni
          // etkinleştirdiyse, oturum geçerli olsa bile Ana Sayfa'ya
          // geçmeden önce biyometrik onay istiyoruz — banka uygulamalarında
          // olduğu gibi ekstra bir güvenlik katmanı.
          if (ThemeController().biometricLockEnabled.value) {
            final available = await BiometricService().isAvailable();
            if (available) {
              final confirmed = await BiometricService().authenticate();
              if (!confirmed) {
                if (mounted) context.go('/login');
                return;
              }
            }
          }

          if (mounted) {
            context.go('/home');
            return;
          }
        } catch (_) {
          // Token geçersiz/süresi dolmuşsa normal giriş ekranına düş.
        }
      }
      if (mounted) context.go('/login');
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Kullanıcı isteği: açılış ekranı arka planı, uygulamanın geri
      // kalanıyla (beyaz) aynı olmalı — önceden koyu lacivertti.
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 10)),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: _logoAvailable
                    ? Image.asset(
                        'assets/images/entpa_logo.png',
                        errorBuilder: (context, error, stackTrace) {
                          // Logo dosyası henüz eklenmemiş — yer tutucu ikona düş.
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _logoAvailable = false);
                          });
                          return const Icon(Icons.local_fire_department, size: 80, color: AppColors.brand);
                        },
                      )
                    : const Icon(Icons.local_fire_department, size: 80, color: AppColors.brand),
              ),
              const SizedBox(height: 32),
              const Text(
                'ENTPA',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'MÜHENDİSLİK HİZMETİ',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
