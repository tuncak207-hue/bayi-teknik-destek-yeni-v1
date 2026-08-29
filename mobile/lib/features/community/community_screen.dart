import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/current_user.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
import '../../core/widgets/design_system.dart';
import '../../core/events/notification_badge_bus.dart';

// Gruplarla tutarlı olsun diye aynı kategori isimlerini kullanıyoruz.
const _kTags = ['Yangın Alarm', 'Kamera', 'Honeywell', 'Hanwha', 'Teknik Destek'];

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _posts = [];
  bool _loading = true;
  String? _selectedTag; // null = Tümü

  @override
  void initState() {
    super.initState();
    _load();
    // Bu ekranı ziyaret etmek, Bayilere Sor bildirimlerini okundu işaretler
    // — önceden Ana Sayfa'daki rozet buraya girip çıksanız bile kalıyordu.
    _dio.post('/notifications/mark-category-read/community').then((_) => NotificationBadgeBus.bump());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _dio.get('/community/posts', queryParameters: _selectedTag != null ? {'tag': _selectedTag} : null);
    setState(() {
      _posts = res.data;
      _loading = false;
    });
  }

  Future<void> _openCreateSheet() async {
    // iOS'ta Cupertino geçiş animasyonu (sağdan kayarak gelen, kenardan
    // geri kaydırılabilen) — Android'de standart Material tam ekran
    // diyalog geçişi kullanılır. Kullanıcı isteği: "android ve ios
    // görünümüne çevir."
    final route = Platform.isIOS
        ? CupertinoPageRoute<bool>(builder: (_) => const _CreatePostSheet(), fullscreenDialog: true)
        : MaterialPageRoute<bool>(builder: (_) => const _CreatePostSheet(), fullscreenDialog: true);
    final created = await Navigator.push<bool>(context, route);
    if (created == true) _load();
  }

  /// Kullanıcı isteği: "bayilere sorda düzenleme ekle" — kendi
  /// gönderisini düzenleyebilmesi için aynı oluşturma ekranını, mevcut
  /// veriyle önceden doldurulmuş olarak açar.
  Future<void> _editPost(dynamic post) async {
    final route = Platform.isIOS
        ? CupertinoPageRoute<bool>(builder: (_) => _CreatePostSheet(existingPost: post), fullscreenDialog: true)
        : MaterialPageRoute<bool>(builder: (_) => _CreatePostSheet(existingPost: post), fullscreenDialog: true);
    final updated = await Navigator.push<bool>(context, route);
    if (updated == true) _load();
  }

  Future<void> _deletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gönderiyi Sil'),
        content: const Text('Bu gönderiyi (ve tüm yorumlarını) silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil', style: TextStyle(color: AppColors.navy)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _dio.delete('/community/posts/$postId');
    setState(() => _posts.removeWhere((p) => p['id'] == postId));
  }

  @override
  Widget build(BuildContext context) {
    final myId = CurrentUser().id;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      floatingActionButton: StandardFab(label: 'Soru Paylaş', onPressed: _openCreateSheet),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: Column(
        children: [
          AppPageHeader(
            title: 'Bayilere Sor',
            titleBadge: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '${_posts.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.sm),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TagChip(label: 'Tümü', selected: _selectedTag == null, onTap: () {
                    setState(() => _selectedTag = null);
                    _load();
                  }),
                  const SizedBox(width: 6),
                  ..._kTags.map((t) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _TagChip(
                          label: t,
                          selected: _selectedTag == t,
                          onTap: () {
                            setState(() => _selectedTag = t);
                            _load();
                          },
                        ),
                      )),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty
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
                                  icon: Icons.forum_outlined,
                                  title: 'Henüz bir paylaşım yok',
                                  description: 'Sağ alttaki butondan diğer bayilere soru sorabilirsiniz.',
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
                          itemCount: _posts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final p = _posts[index];
                            final author = p['author'];
                            final commentCount = p['_count']?['comments'] ?? 0;
                            final isMine = author != null && author['id'] == myId;
                            final companyInitial = (author?['company'] as String?)?.isNotEmpty == true
                                ? (author['company'] as String).characters.first.toUpperCase()
                                : '?';
                            return StandardCard(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              onTap: () => context.push('/community/${p['id']}').then((_) => _load()),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [AppColors.primary.withOpacity(0.14), AppColors.primary.withOpacity(0.06)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(companyInitial, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 16)),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: AppColors.textPrimary, letterSpacing: -0.2)),
                                        const SizedBox(height: 4),
                                        Text(
                                          p['body'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Text(
                                              author != null ? '${author['company']}' : 'Bayi',
                                              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(width: 10),
                                            CardFooterMeta(icon: Icons.chat_bubble_outline, label: '$commentCount'),
                                            if (p['tag'] != null) ...[
                                              const SizedBox(width: 10),
                                              StatusBadge(label: p['tag'], tone: AppStatusTone.neutral),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isMine) ...[
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                                      onPressed: () => _editPost(p),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 19, color: Colors.grey),
                                      onPressed: () => _deletePost(p['id']),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    ),
                                  ],
                                ],
                              ),
                            );
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

class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TagChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.brand,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.navy, fontWeight: FontWeight.w700, fontSize: 12),
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? Colors.transparent : Colors.grey.shade200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  final dynamic existingPost;
  const _CreatePostSheet({this.existingPost});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final Dio _dio = ApiClient().dio;
  late final _titleController = TextEditingController(text: widget.existingPost?['title'] ?? '');
  late final _bodyController = TextEditingController(text: widget.existingPost?['body'] ?? '');
  late String? _tag = widget.existingPost?['tag'];
  bool _submitting = false;

  bool get _isEditing => widget.existingPost != null;

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty || _bodyController.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      final payload = {
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        if (_tag != null) 'tag': _tag,
      };
      if (_isEditing) {
        await _dio.patch('/community/posts/${widget.existingPost['id']}', data: payload);
      } else {
        await _dio.post('/community/posts', data: payload);
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Platform.isIOS ? _buildIosScaffold(context) : _buildAndroidScaffold(context);
  }

  // ============================================================
  // iOS — Cupertino navigasyon çubuğu + Cupertino metin alanları
  // (imleç, seçim tutamaçları, geri kaydırma jesti hep native His).
  // ============================================================
  Widget _buildIosScaffold(BuildContext context) {
    final canSubmit = _titleController.text.trim().isNotEmpty && _bodyController.text.trim().isNotEmpty && !_submitting;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 16)),
        ),
        middle: Text(_isEditing ? 'Gönderiyi Düzenle' : 'Soru Paylaş', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: canSubmit ? _submit : null,
          child: _submitting
              ? const CupertinoActivityIndicator()
              : Text(
                  'Gönder',
                  style: TextStyle(
                    color: canSubmit ? CupertinoColors.activeBlue : CupertinoColors.systemGrey3,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 12),
                  CupertinoTextField.borderless(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    placeholder: 'Başlık',
                    placeholderStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: CupertinoColors.systemGrey3),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: CupertinoColors.black, height: 1.25),
                    padding: EdgeInsets.zero,
                    maxLines: null,
                  ),
                  const SizedBox(height: 4),
                  Container(height: 1, color: CupertinoColors.separator),
                  const SizedBox(height: 16),
                  CupertinoTextField.borderless(
                    controller: _bodyController,
                    onChanged: (_) => setState(() {}),
                    placeholder: 'Sorununuzu ya da deneyiminizi anlatın...',
                    placeholderStyle: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey3, height: 1.5),
                    style: const TextStyle(fontSize: 16, color: CupertinoColors.black, height: 1.5),
                    padding: EdgeInsets.zero,
                    minLines: 6,
                    maxLines: null,
                  ),
                ],
              ),
            ),
            _buildTagBar(border: CupertinoColors.separator),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Android — Material AppBar + standart Material metin alanları
  // (dalga (ripple) efekti, Android imleç/seçim davranışı).
  // ============================================================
  Widget _buildAndroidScaffold(BuildContext context) {
    final canSubmit = _titleController.text.trim().isNotEmpty && _bodyController.text.trim().isNotEmpty && !_submitting;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppPageHeader(
        backgroundColor: Colors.white,
        title: _isEditing ? 'Gönderiyi Düzenle' : 'Soru Paylaş',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: canSubmit ? _submit : null,
              child: _submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      'PAYLAŞ',
                      style: TextStyle(
                        color: canSubmit ? Colors.black : Colors.grey.shade300,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black, height: 1.25),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Başlık',
                      hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.grey.shade300),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bodyController,
                    onChanged: (_) => setState(() {}),
                    minLines: 6,
                    maxLines: null,
                    style: const TextStyle(fontSize: 16, color: Colors.black, height: 1.5),
                    decoration: InputDecoration(
                      hintText: 'Sorununuzu ya da deneyiminizi anlatın...',
                      hintStyle: TextStyle(fontSize: 16, color: Colors.grey.shade300, height: 1.5),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            _buildTagBar(border: Colors.grey.shade200),
          ],
        ),
      ),
    );
  }

  /// Kategori sekme çubuğu — iki platformda da aynı (nötr bir bileşen).
  Widget _buildTagBar({required Color border}) {
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
      padding: const EdgeInsets.symmetric(vertical: 12),
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              // Sığdığı sürece ortalı, sığmadığında normal şekilde
              // kaydırılabilir — kullanıcı isteği: "sayfanın altında
              // ama ortalı olsun."
              constraints: BoxConstraints(minWidth: constraints.maxWidth - 40),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _kTags.map((t) {
            final selected = _tag == t;
            return GestureDetector(
              onTap: () => setState(() => _tag = selected ? null : t),
              child: Padding(
                padding: const EdgeInsets.only(right: 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                        color: selected ? Colors.black : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(width: 20, height: 2, color: selected ? Colors.black : Colors.transparent),
                  ],
                ),
              ),
            );
          }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
