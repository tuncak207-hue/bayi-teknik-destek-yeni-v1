import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/storage/offline_documents_store.dart';
import '../../core/auth/current_user.dart';

/// Not: PDF, uygulama içinde gömülü bir görüntüleyici yerine cihazın
/// KENDİ PDF uygulamasıyla (Google Drive, Adobe Reader, vb.) açılıyor.
/// Bu, sayfa-atlama hassasiyeti sunmaz (sadece bir hedef sayfa bilgisi
/// gösterilir) ama gerçek, çalışan bir doküman görüntüleme deneyimidir.
class DocumentViewerScreen extends StatefulWidget {
  final String documentId;
  final int? page;

  const DocumentViewerScreen({super.key, required this.documentId, this.page});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final Dio _dio = ApiClient().dio;
  // Cloudflare R2'nin imzalı URL'lerini indirmek için ayrı, "çıplak" bir Dio
  // örneği kullanıyoruz. `ApiClient().dio` her isteğe otomatik olarak bizim
  // oturum jetonumuzu (Authorization: Bearer ...) ekliyor — bu, R2'nin
  // kendi imza bilgisiyle (URL içinde) çakışıp 400 hatasına sebep oluyordu.
  final Dio _fileDownloader = Dio();
  final _offlineStore = OfflineDocumentsStore();
  String? _signedUrl;
  Map<String, dynamic>? _document;
  bool _loading = true;
  bool _opening = false;
  bool _downloading = false;
  bool _favorited = false;
  bool _isOffline = false; // ağ hatası oldu ama yerel kopya varsa true
  String? _localPath;
  String? _error;
  List<dynamic> _notes = [];
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    try {
      final res = await _dio.get('/documents/${widget.documentId}/notes');
      if (mounted) setState(() => _notes = res.data);
    } catch (_) {
      // Notlar ikincil bir bilgi, sessizce yut.
    }
  }

  Future<void> _addNote() async {
    final content = _noteController.text.trim();
    if (content.isEmpty) return;
    _noteController.clear();
    await _dio.post('/documents/${widget.documentId}/notes', data: {'content': content});
    _loadNotes();
  }

  Future<void> _deleteNote(String noteId) async {
    await _dio.delete('/documents/${widget.documentId}/notes/$noteId');
    _loadNotes();
  }

  Future<void> _load() async {
    // Önce yerel (indirilmiş) kopya var mı diye bakalım — internet olmasa bile
    // dosyanın kendisini ve temel bilgilerini gösterebiliriz.
    final offline = await _offlineStore.get(widget.documentId);
    if (offline != null && await File(offline['localPath']).exists()) {
      setState(() {
        _localPath = offline['localPath'];
        _document = offline;
      });
    }

    try {
      final results = await Future.wait([
        _dio.get('/documents/${widget.documentId}/signed-url'),
        _dio.get('/documents/${widget.documentId}'),
      ]);
      setState(() {
        _signedUrl = results[0].data as String;
        _document = results[1].data;
        _loading = false;
        _isOffline = false;
      });
    } catch (e) {
      // Ağ hatası: eğer yerel kopya varsa çevrimdışı modda devam et,
      // yoksa gerçek bir hata göster.
      setState(() {
        _loading = false;
        _isOffline = _localPath != null;
        _error = _localPath == null ? 'Doküman açılamadı.' : null;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final res = await _dio.post('/favorites/documents/${widget.documentId}');
    setState(() => _favorited = res.data['favorited'] == true);
  }

  Future<void> _openDocument() async {
    setState(() => _opening = true);
    try {
      String pathToOpen;
      if (_localPath != null) {
        // Yerel kopya varsa doğrudan onu aç — internet gerekmez.
        pathToOpen = _localPath!;
      } else {
        if (_signedUrl == null) return;
        final tempDir = await getTemporaryDirectory();
        final rawTitle = (_document?['title'] ?? 'dokuman').toString();
        var fileName = rawTitle.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
        if (fileName.isEmpty) fileName = 'dokuman'; // başlık sadece özel karakterlerden oluşuyorsa boş kalabilirdi
        pathToOpen = '${tempDir.path}/$fileName.pdf';
        await _fileDownloader.download(_signedUrl!, pathToOpen);
      }

      final result = await OpenFilex.open(pathToOpen);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dosya açılamadı: ${result.message}')),
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('[document_viewer] Dokümanı açma hatası: $e');
      if (e is DioException) {
        // ignore: avoid_print
        print('[document_viewer] R2 cevap gövdesi: ${e.response?.data}');
        // ignore: avoid_print
        print('[document_viewer] İstek yapılan URL: ${e.requestOptions.uri}');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Doküman açılırken bir hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  /// Dokümanı kalıcı olarak cihaza indirir — internet olmadan da
  /// "Dokümanı Aç" ile açılabilsin diye.
  Future<void> _downloadForOffline() async {
    if (_signedUrl == null) return;
    setState(() => _downloading = true);
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final offlineDir = Directory('${docsDir.path}/offline_documents');
      if (!await offlineDir.exists()) await offlineDir.create(recursive: true);

      final fileName = (_document?['title'] ?? 'dokuman').toString().replaceAll(RegExp(r'[^\w\s-]'), '');
      final path = '${offlineDir.path}/${widget.documentId}_$fileName.pdf';

      await _fileDownloader.download(_signedUrl!, path);
      await _offlineStore.save(
        documentId: widget.documentId,
        title: _document?['title'] ?? 'Doküman',
        brand: _document?['brand'] ?? '',
        model: _document?['model'] ?? '',
        localPath: path,
      );

      setState(() => _localPath = path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doküman indirildi, artık internetsiz açılabilir.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İndirme başarısız oldu.')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _removeOfflineCopy() async {
    if (_localPath != null) {
      final file = File(_localPath!);
      if (await file.exists()) await file.delete();
    }
    await _offlineStore.remove(widget.documentId);
    setState(() => _localPath = null);
  }

  /// Önceden sadece güncel versiyon görülebiliyordu — eski bir versiyonu
  /// açmak/karşılaştırmak imkansızdı. Şimdi bir alt sayfa (bottom sheet)
  /// ile tüm versiyonlar listeleniyor, her birine ayrı ayrı girilip
  /// cihazın kendi uygulamasıyla açılabiliyor.
  Future<void> _showVersionHistory() async {
    final versions = (_document!['versions'] as List).toList()
      ..sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Geçmiş Versiyonlar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy)),
              const SizedBox(height: AppSpacing.sm),
              ...versions.map((v) {
                final isCurrent = v['isCurrent'] == true;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isCurrent ? Icons.check_circle : Icons.history,
                    color: isCurrent ? Colors.green : Colors.grey.shade500,
                  ),
                  title: Text('Versiyon ${v['version'] ?? '?'}${isCurrent ? ' (Güncel)' : ''}'),
                  subtitle: v['createdAt'] != null ? Text(v['createdAt'].toString().substring(0, 10)) : null,
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () async {
                    Navigator.pop(context);
                    await _openSpecificVersion(v['id']);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSpecificVersion(String versionId) async {
    try {
      final res = await _dio.get('/documents/${widget.documentId}/versions/$versionId/signed-url');
      final url = res.data as String;
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/versiyon_$versionId.pdf';
      await _fileDownloader.download(url, path);
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu versiyon açılamadı.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: Text(widget.page != null ? 'Doküman — Sayfa ${widget.page}' : 'Doküman'),
        actions: [
          if (!_loading && _error == null) ...[
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Paylaş',
              onPressed: () {
                final title = _document?['title'] ?? 'Doküman';
                final brand = _document?['brand'] ?? '';
                final model = _document?['model'] ?? '';
                Share.share('$title\n$brand / $model\n\n(Bayi Teknik Destek uygulamasından paylaşıldı)');
              },
            ),
            IconButton(
              icon: Icon(_favorited ? Icons.bookmark : Icons.bookmark_border),
              tooltip: 'Favorilere ekle',
              onPressed: _toggleFavorite,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    if (_isOffline)
                      Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(AppSpacing.radius),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_off_outlined, size: 18, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'İnternet bağlantısı yok — indirilmiş kopya gösteriliyor.',
                                style: TextStyle(fontSize: 12.5, color: Colors.blue.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.navy.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(AppSpacing.radius),
                              ),
                              child: const Icon(Icons.picture_as_pdf_outlined, size: 36, color: AppColors.navy),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _document?['title'] ?? 'Doküman',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_document?['brand'] ?? ''} / ${_document?['model'] ?? ''}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            if (widget.page != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Chip(label: Text('İlgili sayfa: ${widget.page}')),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _opening ? null : _openDocument,
                                icon: _opening
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.open_in_new),
                                label: Text(_opening ? 'Açılıyor...' : 'Dokümanı Aç'),
                              ),
                            ),
                            if (!_isOffline) ...[
                              const SizedBox(height: AppSpacing.xs),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _downloading
                                      ? null
                                      : (_localPath != null ? _removeOfflineCopy : _downloadForOffline),
                                  icon: _downloading
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Icon(_localPath != null ? Icons.offline_pin : Icons.download_outlined),
                                  label: Text(
                                    _downloading
                                        ? 'İndiriliyor...'
                                        : (_localPath != null ? 'İndirildi (Kaldır)' : 'Çevrimdışı İndir'),
                                  ),
                                ),
                              ),
                            ],
                            if (!_isOffline && (_document?['versions'] as List?)?.length != null && (_document!['versions'] as List).length > 1) ...[
                              const SizedBox(height: AppSpacing.xs),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: _showVersionHistory,
                                  icon: const Icon(Icons.history, size: 18),
                                  label: Text('Geçmiş Versiyonlar (${(_document!['versions'] as List).length})'),
                                ),
                              ),
                            ],
                            if (widget.page != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Not: Doküman cihazınızın kendi PDF uygulamasıyla açılır, '
                                'otomatik olarak ${widget.page}. sayfaya gidilmez — sayfa numarasını yukarıda '
                                'belirttik, dokümanı açtıktan sonra elle o sayfaya gidebilirsiniz.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildNotesSection(),
                  ],
                ),
    );
  }

  /// Doküman notları: tüm bayilerin paylaştığı, o dokümana özel kısa
  /// notlar — "bu devre şeması X binası için kullanıldı" gibi pratik
  /// bilgileri ekip içinde paylaşmak için.
  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notlar', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(hintText: 'Bir not ekleyin...', isDense: true),
                    onSubmitted: (_) => _addNote(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, size: 20), onPressed: _addNote),
              ],
            ),
            if (_notes.isNotEmpty) ...[
              const Divider(),
              ..._notes.map((n) {
                final author = n['user'];
                final isMine = author != null && author['id'] == CurrentUser().id;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n['content'] ?? '', style: const TextStyle(fontSize: 13.5)),
                            Text(
                              '${author?['company'] ?? 'Bayi'} · ${author?['firstName'] ?? ''}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      if (isMine)
                        InkWell(
                          onTap: () => _deleteNote(n['id']),
                          child: Icon(Icons.close, size: 16, color: Colors.grey.shade400),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
