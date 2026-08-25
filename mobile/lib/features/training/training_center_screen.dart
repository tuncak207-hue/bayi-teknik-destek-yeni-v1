import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_player/video_player.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
import '../../core/events/notification_badge_bus.dart';

/// Eğitim Merkezi — bayilerin video ve doküman (PDF) eğitim içeriklerini
/// düzenli, kategorilere ayrılmış şekilde görüntüleyebildiği ekran.
class TrainingCenterScreen extends StatefulWidget {
  const TrainingCenterScreen({super.key});

  @override
  State<TrainingCenterScreen> createState() => _TrainingCenterScreenState();
}

class _TrainingCenterScreenState extends State<TrainingCenterScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _contents = [];
  bool _loading = true;
  String? _downloadingId;

  @override
  void initState() {
    super.initState();
    _load();
    _dio.post('/notifications/mark-category-read/training').then((_) => NotificationBadgeBus.bump());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _dio.get('/training');
    setState(() {
      _contents = res.data;
      _loading = false;
    });
  }

  Future<void> _open(dynamic content) async {
    if (content['type'] == 'VIDEO') {
      final res = await _dio.get('/training/${content['id']}/url');
      final url = res.data as String;
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _VideoPlayerScreen(title: content['title'], url: url)),
      );
      return;
    }

    setState(() => _downloadingId = content['id']);
    try {
      final res = await _dio.get('/training/${content['id']}/url');
      final url = res.data as String;
      final dir = await getTemporaryDirectory();
      // ÖNEMLİ: Önceden dosya adı her zaman ".pdf" ile sabitlenmişti — bu
      // yüzden Word/Excel/PowerPoint gibi PDF olmayan dokümanlar
      // indirildiğinde yanlış uzantıyla kaydediliyor, cihazın doğru
      // uygulamayla açması engelleniyordu. Artık gerçek uzantı, sunucudan
      // gelen dosya adresinden (URL) çıkarılıyor.
      final extension = _extensionFromUrl(url);
      final path = '${dir.path}/${content['title']}$extension';
      await Dio().download(url, path);
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doküman açılamadı.')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  /// R2/depolama URL'i genelde ".../klasör/uuid-orijinal-dosya-adi.xlsx?imza..."
  /// şeklindedir — sorgu parametrelerini atıp gerçek dosya uzantısını
  /// (varsa) çıkarır. Bulamazsa güvenli bir varsayılan olarak boş kalır
  /// (cihaz uzantısız da olsa içerik türünü tahmin etmeye çalışır).
  String _extensionFromUrl(String url) {
    final withoutQuery = url.split('?').first;
    final lastDot = withoutQuery.lastIndexOf('.');
    final lastSlash = withoutQuery.lastIndexOf('/');
    if (lastDot > lastSlash && lastDot != -1) {
      final ext = withoutQuery.substring(lastDot);
      if (ext.length <= 6) return ext; // ".xlsx" gibi makul uzunlukta olmalı
    }
    return '';
  }

  Map<String, List<dynamic>> get _grouped {
    final map = <String, List<dynamic>>{};
    for (final c in _contents) {
      final category = (c['category'] as String?)?.trim();
      final key = (category == null || category.isEmpty) ? 'Genel' : category;
      map.putIfAbsent(key, () => []).add(c);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Eğitim Merkezi',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.navy, letterSpacing: -0.7, height: 1.1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _contents.isEmpty
                    ? AppEmptyState(
                        icon: Icons.school_outlined,
                        title: 'Henüz eğitim içeriği eklenmedi',
                        description: 'Admin yeni video veya doküman ekleyince burada görünecek.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          children: [
                      ...grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
                            child: Text(
                              entry.key.toUpperCase(),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 0.6),
                            ),
                          ),
                          ...entry.value.map((c) {
                            final isVideo = c['type'] == 'VIDEO';
                            final isDownloading = _downloadingId == c['id'];
                            return Container(
                              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: isDownloading ? null : () => _open(c),
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppSpacing.sm),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: isVideo
                                                  ? [AppColors.brand, AppColors.brand.withValues(alpha: 0.7)]
                                                  : [AppColors.navy, AppColors.navy.withValues(alpha: 0.7)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Icon(
                                            isVideo ? Icons.play_arrow_rounded : Icons.picture_as_pdf_outlined,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(c['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.navy)),
                                              if ((c['description'] as String?)?.isNotEmpty == true) ...[
                                                const SizedBox(height: 3),
                                                Text(c['description'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.3)),
                                              ],
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: (isVideo ? AppColors.brand : AppColors.navy).withValues(alpha: 0.07),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  isVideo ? 'VİDEO' : 'DOKÜMAN',
                                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: isVideo ? AppColors.brand : AppColors.navy, letterSpacing: 0.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        isDownloading
                                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                            : Icon(Icons.chevron_right, color: Colors.grey.shade300),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    }).toList(),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlayerScreen extends StatefulWidget {
  final String title;
  final String url;
  const _VideoPlayerScreen({required this.title, required this.url});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() => _initialized = true);
        _controller.play();
      }
    }).catchError((e) {
      if (mounted) setState(() => _error = 'Video oynatılamadı.');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(widget.title)),
      body: Center(
        child: _error != null
            ? Text(_error!, style: const TextStyle(color: Colors.white))
            : _initialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(_controller),
                        VideoProgressIndicator(_controller, allowScrubbing: true, colors: const VideoProgressColors(playedColor: AppColors.brand)),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(color: Colors.white),
      ),
      floatingActionButton: _initialized
          ? FloatingActionButton(
              backgroundColor: AppColors.brand,
              onPressed: () => setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play()),
              child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
            )
          : null,
    );
  }
}
