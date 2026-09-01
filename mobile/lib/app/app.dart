import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../l10n/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../core/localization/locale_controller.dart';
import 'router.dart';

class BayiTeknikDestekApp extends StatelessWidget {
  const BayiTeknikDestekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: LocaleController().locale,
      builder: (context, locale, _) {
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
                  // Kullanıcı isteği: "İngilizce dil desteği ekle" —
                  // locale null ise cihazın sistem dili kullanılır
                  // (desteklenmiyorsa Türkçe'ye düşer, çünkü Türkçe
                  // şablon/varsayılan ARB dosyası).
                  locale: locale,
                  supportedLocales: const [
                    Locale('tr'),
                    Locale('en'),
                  ],
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  routerConfig: appRouter,
                  builder: (context, child) {
                    final scaled = MediaQuery(
                      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fontScale)),
                      child: child!,
                    );

                    final isDark = themeMode == ThemeMode.dark ||
                        (themeMode == ThemeMode.system &&
                            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
                    return AnnotatedRegion<SystemUiOverlayStyle>(
                      value: SystemUiOverlayStyle(
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
      },
    );
  }
}
