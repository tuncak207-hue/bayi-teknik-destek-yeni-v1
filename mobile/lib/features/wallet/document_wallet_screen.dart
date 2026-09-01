import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_system.dart';
import '../../core/widgets/app_components.dart';

const Map<String, String> _kCategoryLabels = {
  'ISG': 'İSG Evrakları',
  'CERTIFICATE': 'Sertifikalar',
  'TRAINING': 'Eğitim Belgeleri',
  'AUTHORIZATION': 'Yetki Belgeleri',
  'OTHER': 'Diğer Belgeler',
};

/// Evrak Çantası — bayi çalışanlarının kendi evraklarını kategorilere
/// ayırarak sakladığı, görüntüleyip paylaşabildiği kişisel belge alanı.
class DocumentWalletScreen extends StatefulWidget {
  const DocumentWalletScreen({super.key});

  @override
  State<DocumentWalletScreen> createState() => _DocumentWalletScreenState();
}

class _DocumentWalletScreenState extends State<DocumentWalletScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _documents = [];
  bool _loading = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _dio.get('/wallet');
    setState(() {
      _documents = res.data;
      _loading = false;
    });
  }

  Future<void> _addDocument() async {
    // ÖNEMLİ: "Dosyadan Yükle" (file_picker) tekrar denendi ama bu
    // proje ortamındaki paket kombinasyonuyla (file_picker'ın kendi
    // derlenmiş kütüphanesi ile başka bir paketin gerektirdiği
    // flutter_plugin_android_lifecycle sürümü arasında) kalıcı bir
    // uyumsuzluk tespit edildi — compileSdk yükseltmek bunu çözmüyor,
    // paketin kendisinden kaynaklanıyor. Bu yüzden bilinçli olarak
    // tekrar kaldırıldı. Kamera/galeri sorunsuz çalışıyor.
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera ile çek'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden Seç'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    final source = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    final filePath = picked.path;
    final fileName = picked.name;
    if (!mounted) return;

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _DocumentMetaSheet(),
    );
    if (result == null) return;

    setState(() => _loading = true);
    try {
      final formData = FormData.fromMap({
        'name': result['name'],
        'category': result['category'],
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      await _dio.post('/wallet', data: formData);
      _load();
    } catch (e) {
      // ÖNEMLİ DÜZELTME: "kaydet çalışmıyor" — hata yakalama hiç yoktu,
      // bir sorun olursa (backend hatası, ağ sorunu) sessizce yutuluyordu.
      if (!mounted) return;
      String message = 'Kaydedilemedi, tekrar deneyin.';
      if (e is DioException) {
        final serverMessage = e.response?.data?['message'];
        if (serverMessage is String && serverMessage.isNotEmpty) message = serverMessage;
        if (e.response == null) message = 'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.navy));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editMeta(dynamic doc) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DocumentMetaSheet(initialName: doc['name'], initialCategory: doc['category']),
    );
    if (result == null) return;
    try {
      await _dio.patch('/wallet/${doc['id']}', data: result);
      _load();
    } catch (e) {
      if (!mounted) return;
      String message = 'Kaydedilemedi, tekrar deneyin.';
      if (e is DioException) {
        final serverMessage = e.response?.data?['message'];
        if (serverMessage is String && serverMessage.isNotEmpty) message = serverMessage;
        if (e.response == null) message = 'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.navy));
    }
  }

  Future<void> _viewDocument(dynamic doc) async {
    setState(() => _busyId = doc['id']);
    try {
      final res = await _dio.get('/wallet/${doc['id']}/url');
      final url = res.data as String;
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${doc['name']}${_extensionFromUrl(url)}';
      await Dio().download(url, path);
      await OpenFilex.open(path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Belge açılamadı.')));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _shareDocument(dynamic doc) async {
    setState(() => _busyId = doc['id']);
    try {
      final res = await _dio.get('/wallet/${doc['id']}/url');
      final url = res.data as String;
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${doc['name']}${_extensionFromUrl(url)}';
      await Dio().download(url, path);
      await Share.shareXFiles([XFile(path)]);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// Önceden dosya adı her zaman ".jpg" ile sabitlenmişti — artık PDF/Word/
  /// Excel gibi dosyalar da eklenebildiği için gerçek uzantı, sunucudan
  /// gelen adresten (URL) çıkarılıyor.
  String _extensionFromUrl(String url) {
    final withoutQuery = url.split('?').first;
    final lastDot = withoutQuery.lastIndexOf('.');
    final lastSlash = withoutQuery.lastIndexOf('/');
    if (lastDot > lastSlash && lastDot != -1) {
      final ext = withoutQuery.substring(lastDot);
      if (ext.length <= 6) return ext;
    }
    return '';
  }

  Future<void> _delete(dynamic doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Belgeyi Sil'),
        content: Text('"${doc['name']}" kalıcı olarak silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sil', style: TextStyle(color: AppColors.navy))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _dio.delete('/wallet/${doc['id']}');
    _load();
  }

  Map<String, List<dynamic>> get _grouped {
    final map = <String, List<dynamic>>{};
    for (final d in _documents) {
      map.putIfAbsent(d['category'] ?? 'OTHER', () => []).add(d);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    return Scaffold(
      appBar: AppPageHeader(
        title: AppLocalizations.of(context)!.qaWallet,
        titleBadge: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '${_documents.length}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFFFFFFF),
      floatingActionButton: StandardFab(label: 'Belge Ekle', onPressed: _addDocument),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _documents.isEmpty
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
                                  icon: Icons.folder_open_outlined,
                                  title: 'Henüz bir belgeniz yok',
                                  description: 'İSG evrakları, sertifikalar, yetki belgeleriniz gibi evraklarınızı burada saklayabilirsiniz.',
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          children: [
                      ..._kCategoryLabels.entries.where((e) => grouped.containsKey(e.key)).map((entry) {
                      final docs = grouped[entry.key]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
                            child: Text(
                              entry.value.toUpperCase(),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 0.6),
                            ),
                          ),
                          ...docs.map((doc) {
                            final isBusy = _busyId == doc['id'];
                            return Container(
                              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.divider),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppColors.navy.withValues(alpha: 0.10), AppColors.brand.withValues(alpha: 0.10)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: const Icon(Icons.description_outlined, color: AppColors.navy, size: 20),
                                ),
                                title: Text(doc['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.navy, letterSpacing: -0.1)),
                                trailing: isBusy
                                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                    : PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                                        onSelected: (v) {
                                          if (v == 'view') _viewDocument(doc);
                                          if (v == 'edit') _editMeta(doc);
                                          if (v == 'share') _shareDocument(doc);
                                          if (v == 'delete') _delete(doc);
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(value: 'view', child: Text('Görüntüle')),
                                          const PopupMenuItem(value: 'edit', child: Text('Adı/Türü Düzenle')),
                                          const PopupMenuItem(value: 'share', child: Text('Paylaş')),
                                          const PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: AppColors.navy))),
                                        ],
                                      ),
                                onTap: isBusy ? null : () => _viewDocument(doc),
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

class _DocumentMetaSheet extends StatefulWidget {
  final String? initialName;
  final String? initialCategory;
  const _DocumentMetaSheet({this.initialName, this.initialCategory});

  @override
  State<_DocumentMetaSheet> createState() => _DocumentMetaSheetState();
}

class _DocumentMetaSheetState extends State<_DocumentMetaSheet> {
  late final _nameController = TextEditingController(text: widget.initialName ?? '');
  late String _category = widget.initialCategory ?? 'OTHER';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        // ÖNEMLİ DÜZELTME: "Kaydet sayfanın altında kalıyor" — önceden
        // sadece klavye yüksekliği (viewInsets.bottom) hesaba
        // katılıyordu, klavye kapalıyken sistem gezinme çubuğunun
        // kendi boşluğu (padding.bottom) unutuluyordu.
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.initialName == null ? 'Belge Bilgileri' : 'Belgeyi Düzenle', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Belge Adı', hintText: 'Örn: İSG Eğitim Sertifikası')),
          const SizedBox(height: AppSpacing.sm),
          const Text('Kategori', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.navy)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kCategoryLabels.entries
                .map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _category == e.key,
                      onSelected: (_) => setState(() => _category = e.key),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.trim().isEmpty) return;
              Navigator.pop(context, {'name': _nameController.text.trim(), 'category': _category});
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
