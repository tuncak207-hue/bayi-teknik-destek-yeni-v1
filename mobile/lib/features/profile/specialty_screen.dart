import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/current_user.dart';
import '../../core/events/notification_badge_bus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/design_system.dart';
import '../../core/widgets/app_components.dart';
import '../../core/pdf/document_pdf_exporter.dart';

const _kAvailableTags = ['Yangın Alarm', 'Kamera', 'Honeywell', 'Hanwha', 'Teknik Destek', 'Erişim Kontrol', 'Yangın Söndürme'];

/// Uzmanlık etiketleri + sertifika/yetkinlik takibi — tek ekranda, çünkü
/// ikisi de "bayinin hangi konuda deneyimli/yetkili olduğu" bilgisini
/// tamamlıyor.
class SpecialtyScreen extends StatefulWidget {
  const SpecialtyScreen({super.key});

  @override
  State<SpecialtyScreen> createState() => _SpecialtyScreenState();
}

class _SpecialtyScreenState extends State<SpecialtyScreen> {
  final Dio _dio = ApiClient().dio;
  List<String> _selectedTags = [];
  List<dynamic> _certifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _dio.post('/notifications/mark-category-read/certification').then((_) => NotificationBadgeBus.bump());
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _dio.get('/users/me'),
      _dio.get('/certifications'),
    ]);
    setState(() {
      _selectedTags = List<String>.from(results[0].data['specialtyTags'] ?? []);
      _certifications = results[1].data;
      _loading = false;
    });
  }

  Future<void> _toggleTag(String tag) async {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
    await _dio.patch('/users/me/specialty-tags', data: {'tags': _selectedTags});
  }

  Future<void> _openAddCertSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddCertificationSheet(),
    );
    if (added == true) _load();
  }

  Future<void> _deleteCert(String id) async {
    await _dio.delete('/certifications/$id');
    _load();
  }

  Future<void> _viewDocument(String certId) async {
    try {
      final res = await _dio.get('/certifications/$certId/document-url');
      final url = res.data as String;
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/sertifika_$certId${_extensionFromUrl(url)}';
      await Dio().download(url, path);
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Belge açılamadı.')),
        );
      }
    }
  }

  /// Önceden dosya adı her zaman ".jpg" ile sabitlenmişti — artık PDF/Word
  /// gibi belgeler de eklenebildiği için gerçek uzantı, adresten çıkarılıyor.
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

  Future<void> _exportCertificatePdf(dynamic cert, {required bool andShare}) async {
    Uint8List? photoBytes;
    if (cert['documentUrl'] != null) {
      photoBytes = await DocumentPdfExporter.downloadSignature(_dio, '/certifications/${cert['id']}/document-url');
    }
    final file = await DocumentPdfExporter.build(
      documentTitle: 'Sertifika — ${cert['brand']} ${cert['title']}',
      dealerName: '${CurrentUser().firstName} ${CurrentUser().lastName}',
      dealerCompany: '',
      infoRows: [
        (label: 'Marka', value: cert['brand'] ?? ''),
        (label: 'Sertifika', value: cert['title'] ?? ''),
        if (cert['expiresAt'] != null) (label: 'Son Geçerlilik', value: (cert['expiresAt'] as String).substring(0, 10)),
      ],
      signatureBytes: photoBytes,
    );
    if (andShare) {
      await DocumentPdfExporter.share(file);
    } else {
      await DocumentPdfExporter.view(file);
    }
  }

  bool _isExpiringSoon(String? expiresAt) {
    if (expiresAt == null) return false;
    final expiry = DateTime.parse(expiresAt);
    return expiry.difference(DateTime.now()).inDays <= 30;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppPageHeader(
        title: AppLocalizations.of(context)!.screenSpecialty,
        titleBadge: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '${_certifications.length}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFFFFFFF),
      // ÖNEMLİ DÜZELTME: "sayfanın altında kalıyor" — SafeArea hiç yoktu.
      body: SafeArea(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const Text('Uzmanlık Alanları', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
                const SizedBox(height: 4),
                Text(
                  'Bayiler listesinde sizinle ilgili gösterilir.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kAvailableTags
                      .map((tag) => FilterChip(
                            label: Text(
                              tag,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            selected: _selectedTags.contains(tag),
                            onSelected: (_) => _toggleTag(tag),
                            backgroundColor: Colors.white,
                            selectedColor: AppColors.navy.withValues(alpha: 0.15),
                            checkmarkColor: AppColors.navy,
                            side: BorderSide(color: AppColors.outline),
                          ))
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('Sertifikalar', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${_certifications.length}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _openAddCertSheet,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ekle'),
                    ),
                  ],
                ),
                if (_certifications.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: StandardCard(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                      child: const AppEmptyState(
                        icon: Icons.verified_outlined,
                        title: 'Henüz sertifika eklenmedi',
                        description: 'Yukarıdaki "Ekle" butonundan yeni bir sertifika ekleyebilirsiniz.',
                      ),
                    ),
                  )
                else
                  ..._certifications.map((c) {
                    final expiringSoon = _isExpiringSoon(c['expiresAt']);
                    return Card(
                      color: expiringSoon ? Colors.amber.shade50 : null,
                      child: ListTile(
                        leading: Icon(
                          expiringSoon ? Icons.warning_amber_outlined : Icons.verified_outlined,
                          color: expiringSoon ? Colors.amber.shade800 : AppColors.navy,
                        ),
                        title: Text('${c['brand']} — ${c['title']}'),
                        subtitle: Text(
                          c['expiresAt'] != null
                              ? 'Son geçerlilik: ${(c['expiresAt'] as String).substring(0, 10)}'
                              : 'Süresiz',
                          style: expiringSoon ? TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w600) : null,
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          onSelected: (v) {
                            if (v == 'document') _viewDocument(c['id']);
                            if (v == 'pdf-view') _exportCertificatePdf(c, andShare: false);
                            if (v == 'pdf-share') _exportCertificatePdf(c, andShare: true);
                            if (v == 'delete') _deleteCert(c['id']);
                          },
                          itemBuilder: (context) => [
                            if (c['documentUrl'] != null)
                              const PopupMenuItem(value: 'document', child: Text('Fotoğrafı Görüntüle')),
                            const PopupMenuItem(value: 'pdf-view', child: Text('PDF Görüntüle')),
                            const PopupMenuItem(value: 'pdf-share', child: Text('PDF Paylaş')),
                            const PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: AppColors.navy))),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
      ),
    );
  }
}

class _AddCertificationSheet extends StatefulWidget {
  const _AddCertificationSheet();

  @override
  State<_AddCertificationSheet> createState() => _AddCertificationSheetState();
}

class _AddCertificationSheetState extends State<_AddCertificationSheet> {
  final Dio _dio = ApiClient().dio;
  final _brandController = TextEditingController();
  final _titleController = TextEditingController();
  DateTime? _expiresAt;
  // Önceden sadece kamera desteği vardı (galeri/dosya hiç yoktu) — artık
  // üçü de mevcut, seçilen kaynak ne olursa olsun burada dosya yolunu ve
  // adını tek tipte tutuyoruz.
  String? _pickedFilePath;
  String? _pickedFileName;
  bool _submitting = false;

  Future<void> _pickPhoto() async {
    // ÖNEMLİ: "Dosyadan Yükle" (file_picker) seçeneği geçici olarak
    // kaldırıldı — file_picker paketi bu projenin mevcut Android eklenti
    // sürümleriyle (flutter_plugin_android_lifecycle) derleme hatası
    // veriyordu. Kamera ve galeri sorunsuz çalışıyor, "Dosyadan Yükle"yi
    // ayrı ve sakin bir turda güvenli şekilde geri ekleyebiliriz.
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
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _pickedFilePath = picked.path;
        _pickedFileName = picked.name;
      });
    }
  }

  Future<void> _submit() async {
    if (_brandController.text.trim().isEmpty || _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen marka ve unvan alanlarını doldurun.'), backgroundColor: AppColors.navy),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await _dio.post('/certifications', data: {
        'brand': _brandController.text.trim(),
        'title': _titleController.text.trim(),
        if (_expiresAt != null) 'expiresAt': _expiresAt!.toIso8601String(),
      });

      if (_pickedFilePath != null) {
        final certId = res.data['id'];
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(_pickedFilePath!, filename: _pickedFileName),
        });
        await _dio.post('/certifications/$certId/document', data: formData);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // ÖNEMLİ DÜZELTME: Hata yakalama hiç yoktu, sessizce yutuluyordu.
      if (!mounted) return;
      String message = 'Kaydedilemedi, tekrar deneyin.';
      if (e is DioException) {
        final serverMessage = e.response?.data?['message'];
        if (serverMessage is String && serverMessage.isNotEmpty) message = serverMessage;
        if (e.response == null) message = 'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.navy));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Yeni Sertifika', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _brandController, decoration: const InputDecoration(labelText: 'Marka (örn. Honeywell)')),
          const SizedBox(height: AppSpacing.xs),
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Sertifika Adı')),
          const SizedBox(height: AppSpacing.xs),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_expiresAt == null ? 'Son geçerlilik tarihi (opsiyonel)' : _expiresAt!.toString().substring(0, 10)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 365)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null) setState(() => _expiresAt = picked);
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: Icon(_pickedFilePath != null ? Icons.check_circle_outline : Icons.attach_file),
            label: Text(_pickedFilePath != null ? 'Belge Eklendi: $_pickedFileName' : 'Sertifika Belgesi Ekle (opsiyonel)'),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
