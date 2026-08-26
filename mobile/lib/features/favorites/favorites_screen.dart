import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
import '../../core/widgets/design_system.dart';
import '../../core/widgets/section_header.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _dio.get('/favorites');
    setState(() {
      _favorites = res.data;
      _loading = false;
    });
  }

  /// Önceden bu ekranda favorilerden kaldırma imkanı hiç yoktu — kullanıcı
  /// kaldırmak için dokümanı/mesajı bulunduğu yere gidip orada tekrar
  /// favori butonuna basmak zorundaydı. Backend'deki toggle uç noktaları
  /// (favorileme = kaldırma) zaten hazırdı, sadece burada bağlı değildi.
  Future<void> _removeDocumentFavorite(String documentId) async {
    await _dio.post('/favorites/documents/$documentId');
    setState(() => _favorites.removeWhere((f) => f['document']?['id'] == documentId));
  }

  Future<void> _removeMessageFavorite(String messageId) async {
    await _dio.post('/chat/messages/$messageId/favorite');
    setState(() => _favorites.removeWhere((f) => f['message']?['id'] == messageId));
  }

  /// Ana Sayfa'da her zaman görünmesi için bir doküman favorisini sabitler.
  Future<void> _togglePin(String favoriteId) async {
    await _dio.post('/favorites/$favoriteId/pin');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Favorilerim',
                    style: AppText.screenTitle,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${_favorites.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _favorites.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          children: [
                            const SizedBox(height: 72),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                              child: StandardCard(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                                child: const AppEmptyState(
                                  icon: Icons.bookmark_border,
                                  title: 'Henüz favori eklemediniz',
                                  description: 'AI cevaplarında bulunan kaydet simgesine dokunarak buraya ekleyebilirsiniz.',
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: _favorites.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                          itemBuilder: (context, index) {
                      final f = _favorites[index];
                      final message = f['message'];
                      final document = f['document'];

                      if (document != null) {
                        final isPinned = f['pinned'] == true;
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.divider),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                            leading: IconAvatar(icon: Icons.picture_as_pdf_outlined, color: AppColors.navy),
                            title: Text(document['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${document['brand']} / ${document['model']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                    color: isPinned ? AppColors.brand : Colors.grey,
                                    size: 20,
                                  ),
                                  tooltip: isPinned ? 'Ana Sayfa\'dan kaldır' : 'Ana Sayfa\'da sabitle',
                                  onPressed: () => _togglePin(f['id']),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.bookmark, color: AppColors.brand),
                                  tooltip: 'Favorilerden kaldır',
                                  onPressed: () => _removeDocumentFavorite(document['id']),
                                ),
                              ],
                            ),
                            onTap: () => context.push('/documents/${document['id']}'),
                          ),
                        );
                      }

                      if (message != null) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.divider),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                IconAvatar(icon: Icons.smart_toy_outlined, color: AppColors.navy),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    message['content'] ?? '',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(height: 1.4),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.bookmark, color: AppColors.brand),
                                  tooltip: 'Favorilerden kaldır',
                                  onPressed: () => _removeMessageFavorite(message['id']),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return const SizedBox.shrink();
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
