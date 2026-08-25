import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

/// Kullanıcı isteği: "uygulama açılırken ekranda slayt dönsün ve bu
/// slaytları sürekli değiştirebilir durumda olayım." Admin panelden
/// yönetilen görseller, burada otomatik olarak (birkaç saniyede bir)
/// kayarak dönüyor. Kullanıcı isterse parmağıyla da kaydırabilir.
class HomeSlideshow extends StatefulWidget {
  const HomeSlideshow({super.key});

  @override
  State<HomeSlideshow> createState() => _HomeSlideshowState();
}

class _HomeSlideshowState extends State<HomeSlideshow> {
  final _dio = ApiClient().dio;
  final _pageController = PageController();
  List<dynamic> _slides = [];
  bool _loading = true;
  int _currentPage = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await _dio.get('/slides');
      if (!mounted) return;
      setState(() {
        _slides = res.data as List<dynamic>;
        _loading = false;
      });
      if (_slides.length > 1) _startAutoPlay();
    } catch (_) {
      // Slaytlar ikincil bir özellik — yüklenemezse Ana Sayfa'nın geri
      // kalanını etkilemeden sessizce görünmez oluyor.
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Kullanıcı isteği: "sürekli dönsün" — her 4 saniyede bir otomatik
  /// olarak bir sonraki slayta geçiyor, sonuncuya gelince başa dönüyor.
  void _startAutoPlay() {
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % _slides.length;
      _pageController.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
    });
  }

  Future<void> _onTapSlide(Map<String, dynamic> slide) async {
    final link = slide['linkUrl'] as String?;
    if (link == null || link.isEmpty) return;
    try {
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Sessizce yut — bozuk bir bağlantı Ana Sayfa'yı etkilemesin.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Yüklenirken ya da hiç slayt yoksa, Ana Sayfa'da hiçbir boşluk
    // bırakmadan (0 yükseklik) tamamen gizleniyor.
    if (_loading) {
      return const SizedBox.shrink();
    }
    if (_slides.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final slide = _slides[index] as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  onTap: () => _onTapSlide(slide),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          slide['imageUrl'] ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppColors.surfaceVariant,
                            child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted),
                          ),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: AppColors.surfaceVariant,
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          },
                        ),
                        if ((slide['title'] as String?)?.isNotEmpty == true)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(14, 20, 14, 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    slide['title'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5),
                                  ),
                                  if ((slide['subtitle'] as String?)?.isNotEmpty == true) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      slide['subtitle'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_slides.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (i) {
              final isActive = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.outlineStrong,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
