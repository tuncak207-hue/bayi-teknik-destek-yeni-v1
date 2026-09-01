import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
import '../../core/widgets/design_system.dart';

class DealerVisitsScreen extends StatefulWidget {
  const DealerVisitsScreen({super.key});

  @override
  State<DealerVisitsScreen> createState() => _DealerVisitsScreenState();
}

class _DealerVisitsScreenState extends State<DealerVisitsScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _visits = [];
  bool _loading = true;

  static const _outcomeLabels = {
    'POSITIVE': 'Olumlu',
    'QUOTE_PENDING': 'Teklif Bekliyor',
    'PROJECT_CREATED': 'Proje Oluştu',
    'ORDER_PENDING': 'Sipariş Bekleniyor',
    'FOLLOW_UP_NEEDED': 'Takip Gerekli',
    'NEGATIVE': 'Olumsuz',
    'NOT_HAPPENED': 'Görüşme Gerçekleşmedi',
    'OTHER': 'Diğer',
  };

  static const _visitTypeLabels = {
    'DEALER_VISIT': 'Bayi Ziyareti',
    'PROJECT_MEETING': 'Proje Görüşmesi',
    'PRODUCT_INTRO': 'Ürün Tanıtımı',
    'TECHNICAL_MEETING': 'Teknik Görüşme',
    'QUOTE_MEETING': 'Teklif Görüşmesi',
    'TRAINING': 'Eğitim',
    'COLLECTION': 'Tahsilat / Ticari Görüşme',
    'OTHER': 'Diğer',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/dealer-visits');
      setState(() {
        _visits = res.data;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const _CreateVisitScreen()));
    // Not: oluşturma sonrası detay ekranına yönlendirildiği için (fotoğraf
    // eklenebilsin diye), geri dönüş değerine bakmadan her zaman
    // tazeliyoruz — zararsız, liste zaten değişmemişse aynı kalır.
    _load();
  }

  AppStatusTone _outcomeTone(String outcome) {
    switch (outcome) {
      case 'POSITIVE':
      case 'PROJECT_CREATED':
        return AppStatusTone.success;
      case 'QUOTE_PENDING':
      case 'ORDER_PENDING':
        return AppStatusTone.pending;
      case 'FOLLOW_UP_NEEDED':
        return AppStatusTone.inProgress;
      case 'NEGATIVE':
        return AppStatusTone.danger;
      default:
        return AppStatusTone.neutral;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      floatingActionButton: StandardFab(label: 'Yeni Ziyaret', onPressed: _openCreate),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _visits.isEmpty
              ? const AppEmptyState(icon: Icons.location_on_outlined, title: 'Henüz ziyaret kaydınız yok', description: 'Sağ alttaki butondan ilk ziyaret raporunuzu oluşturun.')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _visits.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Bayi Ziyaretleri',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.navy, letterSpacing: -0.6, height: 1.1),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('${_visits.length}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
                              ),
                            ],
                          ),
                        );
                      }
                      final v = _visits[index - 1];
                      final needsFollowUp = v['needsFollowUp'] == true && v['followUpDone'] != true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: StandardCard(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => _VisitDetailScreen(visitId: v['id'])),
                          ).then((_) => _load()),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CardHeaderRow(
                                title: v['dealer']?['company'] ?? v['dealerNameFreeText'] ?? 'Bayi belirtilmedi',
                                subtitle: '${_visitTypeLabels[v['visitType']] ?? v['visitType']} · ${v['city'] ?? '—'}',
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  StatusBadge(label: _outcomeLabels[v['outcome']] ?? v['outcome'], tone: _outcomeTone(v['outcome'])),
                                  if (needsFollowUp) ...[
                                    const SizedBox(width: 6),
                                    const StatusBadge(label: 'Takip', tone: AppStatusTone.pending),
                                  ],
                                  const Spacer(),
                                  CardFooterMeta(icon: Icons.event_outlined, label: _formatDate(v['visitDate'])),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      ),
    );
  }
}

class _CreateVisitScreen extends StatefulWidget {
  const _CreateVisitScreen();

  @override
  State<_CreateVisitScreen> createState() => _CreateVisitScreenState();
}

class _CreateVisitScreenState extends State<_CreateVisitScreen> {
  final Dio _dio = ApiClient().dio;
  final _dealerFreeTextController = TextEditingController();
  final _cityController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _visitDate = DateTime.now();
  String? _dealerId;
  List<dynamic> _dealers = [];
  String _visitType = 'DEALER_VISIT';
  String _outcome = 'POSITIVE';
  bool _showOptional = false;

  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  bool _needsFollowUp = false;
  DateTime? _followUpDate;
  final _followUpActionController = TextEditingController();

  bool _loadingDealers = true;
  bool _submitting = false;
  String? _error;

  static const _visitTypeLabels = {
    'DEALER_VISIT': 'Bayi Ziyareti',
    'PROJECT_MEETING': 'Proje Görüşmesi',
    'PRODUCT_INTRO': 'Ürün Tanıtımı',
    'TECHNICAL_MEETING': 'Teknik Görüşme',
    'QUOTE_MEETING': 'Teklif Görüşmesi',
    'TRAINING': 'Eğitim',
    'COLLECTION': 'Tahsilat / Ticari Görüşme',
    'OTHER': 'Diğer',
  };

  static const _outcomeLabels = {
    'POSITIVE': 'Olumlu',
    'QUOTE_PENDING': 'Teklif Bekliyor',
    'PROJECT_CREATED': 'Proje Oluştu',
    'ORDER_PENDING': 'Sipariş Bekleniyor',
    'FOLLOW_UP_NEEDED': 'Takip Gerekli',
    'NEGATIVE': 'Olumsuz',
    'NOT_HAPPENED': 'Görüşme Gerçekleşmedi',
    'OTHER': 'Diğer',
  };

  @override
  void initState() {
    super.initState();
    _loadDealers();
  }

  Future<void> _loadDealers() async {
    try {
      final res = await _dio.get('/users/dealers');
      setState(() {
        _dealers = res.data;
        _loadingDealers = false;
      });
    } catch (_) {
      setState(() => _loadingDealers = false);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(context: context, initialDate: _visitDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (date != null) setState(() => _visitDate = date);
  }

  Future<void> _pickFollowUpDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _followUpDate = date);
  }

  Future<void> _submit() async {
    if (_dealerId == null && _dealerFreeTextController.text.trim().isEmpty) {
      setState(() => _error = 'Bir bayi seçin ya da bayi adını yazın.');
      return;
    }
    if (_notesController.text.trim().isEmpty) {
      setState(() => _error = 'Görüşme notu zorunludur.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final res = await _dio.post('/dealer-visits', data: {
        'visitDate': _visitDate.toIso8601String(),
        'dealerId': _dealerId,
        'dealerNameFreeText': _dealerFreeTextController.text.trim(),
        'city': _cityController.text.trim(),
        'visitType': _visitType,
        'outcome': _outcome,
        'notes': _notesController.text.trim(),
        'contactName': _contactNameController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'needsFollowUp': _needsFollowUp,
        'followUpDate': _followUpDate?.toIso8601String(),
        'followUpAction': _followUpActionController.text.trim(),
      });
      if (mounted) {
        // Ziyaret kaydedildikten hemen sonra, isterlerse fotoğraf
        // ekleyebilecekleri detay ekranına yönlendiriyoruz — kullanıcı
        // isteği: "Fotoğraf eklenebilmeli."
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => _VisitDetailScreen(visitId: res.data['id'], justCreated: true)),
        );
      }
    } catch (e) {
      setState(() => _error = 'Ziyaret kaydedilemedi, tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _dealerFreeTextController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _followUpActionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Uzun, çok alanlı formlarda kaydet butonunu üst çubuğa değil, en
    // alta (mevcut haliyle) koymak daha kullanışlı — bu yüzden burada
    // PlatformFormScaffold yerine sadece üst çubuğun kendisini platforma
    // göre ayırıyoruz, form gövdesi aynı kalıyor.
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        navigationBar: const CupertinoNavigationBar(
          backgroundColor: Color(0xFFFFFFFF),
          border: null,
          middle: Text('Yeni Ziyaret', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
        child: SafeArea(child: _buildForm()),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppPageHeader(title: AppLocalizations.of(context)!.screenNewVisit),
      body: SafeArea(child: _buildForm()),
    );
  }

  Widget _buildForm() {
    return _loadingDealers
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.navy, fontSize: 13)),
                  ),
                StandardCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined, size: 16),
                        label: Text('${_visitDate.day}.${_visitDate.month}.${_visitDate.year}'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _dealerId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Bayi Seçin', border: OutlineInputBorder()),
                        items: _dealers
                            .map<DropdownMenuItem<String>>(
                                (d) => DropdownMenuItem(value: d['id'] as String, child: Text(d['company'] ?? '', overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setState(() => _dealerId = v),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _dealerFreeTextController,
                        decoration: const InputDecoration(labelText: 'Ya da listede yoksa bayi adı yazın', border: OutlineInputBorder(), isDense: true),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'Şehir', border: OutlineInputBorder(), isDense: true),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _visitType,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Ziyaret Türü', border: OutlineInputBorder()),
                        items: _visitTypeLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                        onChanged: (v) => setState(() => _visitType = v!),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _outcome,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Ziyaret Sonucu', border: OutlineInputBorder()),
                        items: _outcomeLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                        onChanged: (v) => setState(() => _outcome = v!),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(labelText: 'Görüşme Notları', hintText: 'Görüşmenin detaylarını yazın...', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: () => setState(() => _showOptional = !_showOptional),
                  icon: Icon(_showOptional ? Icons.remove : Icons.add, size: 18),
                  label: const Text('Görüşülen kişi / takip bilgisi ekle (isteğe bağlı)'),
                ),
                if (_showOptional) ...[
                  const SizedBox(height: AppSpacing.xs),
                  StandardCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Görüşülen Kişi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
                        const SizedBox(height: 8),
                        TextField(controller: _contactNameController, decoration: const InputDecoration(labelText: 'Ad Soyad', border: OutlineInputBorder(), isDense: true)),
                        const SizedBox(height: 8),
                        TextField(controller: _contactPhoneController, decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder(), isDense: true)),
                        const SizedBox(height: 16),
                        const Text('Takip', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Takip gerekiyor', style: TextStyle(fontSize: 13)),
                          value: _needsFollowUp,
                          onChanged: (v) => setState(() => _needsFollowUp = v),
                        ),
                        if (_needsFollowUp) ...[
                          OutlinedButton.icon(
                            onPressed: _pickFollowUpDate,
                            icon: const Icon(Icons.event_outlined, size: 16),
                            label: Text(_followUpDate == null ? 'Takip Tarihi Seç' : '${_followUpDate!.day}.${_followUpDate!.month}.${_followUpDate!.year}'),
                          ),
                          const SizedBox(height: 8),
                          TextField(controller: _followUpActionController, decoration: const InputDecoration(labelText: 'Yapılacak işlem', border: OutlineInputBorder(), isDense: true)),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Ziyareti Kaydet'),
                ),
              ],
            );
  }
}

class _VisitDetailScreen extends StatefulWidget {
  final String visitId;
  final bool justCreated;

  const _VisitDetailScreen({required this.visitId, this.justCreated = false});

  @override
  State<_VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<_VisitDetailScreen> {
  final Dio _dio = ApiClient().dio;
  Map<String, dynamic>? _visit;
  bool _loading = true;
  bool _uploading = false;

  static const _outcomeLabels = _DealerVisitsScreenState._outcomeLabels;
  static const _visitTypeLabels = _DealerVisitsScreenState._visitTypeLabels;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.get('/dealer-visits/${widget.visitId}');
      setState(() {
        _visit = res.data;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(picked.path, filename: 'ziyaret_${DateTime.now().millisecondsSinceEpoch}.jpg'),
      });
      await _dio.post('/dealer-visits/${widget.visitId}/attachment', data: formData);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf eklenemedi, tekrar deneyin.')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Fotoğraf Çek'),
              onTap: () {
                Navigator.pop(context);
                _addPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden Seç'),
              onTap: () {
                Navigator.pop(context);
                _addPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewAttachment(String fileId) async {
    try {
      final res = await _dio.get('/dealer-visits/attachments/$fileId/signed-url');
      // ignore: use_build_context_synchronously
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: Image.network(res.data['url'], fit: BoxFit.contain),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppPageHeader(title: AppLocalizations.of(context)!.screenVisitDetail),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _visit == null
              ? const Center(child: Text('Ziyaret bulunamadı.'))
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    if (widget.justCreated)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 18),
                            SizedBox(width: 8),
                            Expanded(child: Text('Ziyaret kaydedildi. İsterseniz fotoğraf ekleyebilirsiniz.', style: TextStyle(fontSize: 12.5))),
                          ],
                        ),
                      ),
                    StandardCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _visit!['dealer']?['company'] ?? _visit!['dealerNameFreeText'] ?? 'Bayi belirtilmedi',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_visitTypeLabels[_visit!['visitType']] ?? _visit!['visitType']} · ${_visit!['city'] ?? '—'}',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 10),
                          StatusBadge(label: _outcomeLabels[_visit!['outcome']] ?? _visit!['outcome'], tone: AppStatusTone.neutral),
                          const Divider(height: 24),
                          const Text('Görüşme Notları', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.navy)),
                          const SizedBox(height: 6),
                          Text(_visit!['notes'] ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        const Text('Fotoğraflar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.navy)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _uploading ? null : _showPhotoSourceSheet,
                          icon: _uploading
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.add_a_photo_outlined, size: 16),
                          label: const Text('Ekle'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if ((_visit!['attachments'] as List?)?.isEmpty ?? true)
                      Text('Henüz fotoğraf eklenmedi.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade400))
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                        itemCount: (_visit!['attachments'] as List).length,
                        itemBuilder: (context, i) {
                          final f = _visit!['attachments'][i];
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _viewAttachment(f['id']),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: const Icon(Icons.image_outlined, color: AppColors.brand),
                            ),
                          );
                        },
                      ),
                  ],
                ),
    );
  }
}
