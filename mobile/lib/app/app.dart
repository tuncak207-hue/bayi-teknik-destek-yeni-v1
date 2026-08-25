import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import 'router.dart';

class BayiTeknikDestekApp extends StatelessWidget {
  const BayiTeknikDestekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController().mode,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<double>(
          valueListenable: ThemeController().fontScale,
          builder: (context, fontScale, __) {
            return MaterialApp.router(
              title: 'Bayi Teknik Destek',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeMode,
              routerConfig: appRouter,
              builder: (context, child) {
                // Kullanıcının Ayarlar'dan seçtiği yazı boyutu ölçeğini
                // tüm uygulamaya uyguluyoruz — sahada güneş altında/uzaktan
                // okurken büyük yazı tercih edenler için.
                final scaled = MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fontScale)),
                  child: child!,
                );

                // ÖNEMLİ: "Status Bar gri, Navigation Bar siyah görünüyor,
                // uygulamayla uyumsuz" — sebep, hiçbir yerde
                // SystemChrome.setSystemUIOverlayStyle çağrılmıyor olmasıydı,
                // bu yüzden Android kendi varsayılan (gri/siyah) sistem çubuğu
                // temasını çiziyordu. AnnotatedRegion, builder içinde TEK bir
                // yerden TÜM ekranlara (Ana Sayfa, AI, Ara, Mesajlar, Profil,
                // formlar, detay ekranları — hepsi) otomatik uygulanıyor;
                // ayrıca açık/koyu tema değişse bile (isDark kontrolü ile)
                // doğru kontrastı koruyor — kalıcı, merkezi bir çözüm.
                final isDark = themeMode == ThemeMode.dark ||
                    (themeMode == ThemeMode.system &&
                        MediaQuery.platformBrightnessOf(context) == Brightness.dark);
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle(
                    // Durum çubuğunu şeffaf yapıp, uygulamanın kendi
                    // (beyaz/koyu) arka planının altından görünmesini
                    // sağlıyoruz — bu, "gri şerit" sorununu kökten çözüyor.
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
                    systemNavigationBarColor: isDark ? AppColors.ink : Colors.white,
                    systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                    systemNavigationBarDividerColor: Colors.transparent,
                  ),
                  child: scaled,
                );
              },
            );
          },
        );
      },
    );
  }
}
