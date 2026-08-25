import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
import '../../core/widgets/design_system.dart';
import '../../core/widgets/province_district_picker.dart';
import '../../core/pdf/document_pdf_exporter.dart';

const List<String> kTurkishProvinces = [
  'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Amasya', 'Ankara', 'Antalya', 'Artvin',
  'Aydın', 'Balıkesir', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa',
  'Çanakkale', 'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 'Edirne', 'Elazığ', 'Erzincan',
  'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari', 'Hatay', 'Isparta',
  'Mersin', 'İstanbul', 'İzmir', 'Kars', 'Kastamonu', 'Kayseri', 'Kırklareli', 'Kırşehir',
  'Kocaeli', 'Konya', 'Kütahya', 'Malatya', 'Manisa', 'Kahramanmaraş', 'Mardin', 'Muğla',
  'Muş', 'Nevşehir', 'Niğde', 'Ordu', 'Rize', 'Sakarya', 'Samsun', 'Siirt',
  'Sinop', 'Sivas', 'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Şanlıurfa', 'Uşak',
  'Van', 'Yozgat', 'Zonguldak', 'Aksaray', 'Bayburt', 'Karaman', 'Kırıkkale', 'Batman',
  'Şırnak', 'Bartın', 'Ardahan', 'Iğdır', 'Yalova', 'Karabük', 'Kilis', 'Osmaniye', 'Düzce',
];

/// Malzeme listesi geçmişi — sunucuya kaydediliyor, geçmiş listeler
/// görüntülenip düzenlenebiliyor ve artık silinebiliyor.
class BomListScreen extends StatefulWidget {
  const BomListScreen({super.key});

  @override
  State<BomListScreen> createState() => _BomListScreenState();
}

class _BomListScreenState extends State<BomListScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _lists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _dio.get('/bom-lists');
    setState(() {
      _lists = res.data;
      _loading = false;
    });
  }

  Future<void> _openBuilder({dynamic existingList}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BomBuilderScreen(existingList: existingList)),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(dynamic list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Listeyi Sil'),
        content: Text('"${list['title']}" kalıcı olarak silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _dio.delete('/bom-lists/${list['id']}');
    _load();
  }

  String _formatDate(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      floatingActionButton: StandardFab(label: 'Yeni Liste', onPressed: () => _openBuilder()),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: Text(
              'Malzeme Listeleri',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.navy, letterSpacing: -0.6, height: 1.1),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _lists.isEmpty
                    ? AppEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Henüz bir malzeme listeniz yok',
                        description: 'Sağ alttaki butondan yeni bir liste oluşturabilirsiniz.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: _lists.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                          itemBuilder: (context, index) {
                            final l = _lists[index];
                            final items = (l['items'] as List?) ?? [];
                      final location = [l['district'], l['province']].where((s) => s != null && s.toString().isNotEmpty).join(', ');
                      return StandardCard(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        onTap: () => _openBuilder(existingList: l),
                        child: ReferenceCardContent(
                          icon: Icons.receipt_long_outlined,
                          title: l['title'] ?? '',
                          description: location.isNotEmpty ? location : 'Malzeme listesi',
                          iconColor: Colors.white,
                          iconBackground: AppColors.brand,
                          metadata: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              CardFooterMeta(icon: Icons.inventory_2_outlined, label: '${items.length} kalem'),
                              CardFooterMeta(icon: Icons.schedule_outlined, label: _formatDate(l['updatedAt'])),
                            ],
                          ),
                          action: IconButton(
                            tooltip: 'Sil',
                            icon: const Icon(Icons.delete_outline, color: Colors.grey),
                            onPressed: () => _delete(l),
                          ),
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

class _BomItem {
  final nameController = TextEditingController();
  final quantityController = TextEditingController(text: '1');
  final unitController = TextEditingController(text: 'adet');
  final id = UniqueKey();

  _BomItem();

  _BomItem.fromJson(Map<String, dynamic> json) {
    nameController.text = json['name'] ?? '';
    quantityController.text = json['quantity']?.toString() ?? '1';
    unitController.text = json['unit'] ?? 'adet';
  }

  Map<String, dynamic> toJson() => {
        'name': nameController.text,
        'quantity': quantityController.text,
        'unit': unitController.text,
      };

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
  }
}

class BomBuilderScreen extends StatefulWidget {
  final dynamic existingList;
  const BomBuilderScreen({super.key, this.existingList});

  @override
  State<BomBuilderScreen> createState() => _BomBuilderScreenState();
}

class _BomBuilderScreenState extends State<BomBuilderScreen> {
  final Dio _dio = ApiClient().dio;
  // ÖNEMLİ DÜZELTME: Önceden yeni liste oluştururken "Malzeme Listesi"
  // GERÇEK bir metin olarak dolduruluyordu — kullanıcı yazmaya
  // başlamadan önce bunu elle silmek zorunda kalıyordu. Artık sadece
  // mevcut bir listeyi DÜZENLERKEN başlık geliyor, yeni listede alan
  // boş başlıyor ve "Liste Başlığı" bir İPUCU (hint) olarak görünüp
  // ilk harfle birlikte kendiliğinden kayboluyor.
  late final _titleController = TextEditingController(text: widget.existingList?['title'] ?? '');
  late final _descriptionController = TextEditingController(text: widget.existingList?['description'] ?? '');
  String? _district;
  // ÖNEMLİ: Bu alan önceden doğrudan sınıf düzeyinde ilklendiriliyordu
  // (`String? _province = ...widget...`) — Dart'ta "widget", State
  // sınıfının alan ilklendirmeleri sırasında henüz mevcut olmadığı için
  // bu, "Undefined name 'widget'" derleme hatası veriyordu. Artık
  // initState() içinde atanıyor.
  String? _province;
  late final List<_BomItem> _items = widget.existingList != null
      ? (widget.existingList['items'] as List).map((i) => _BomItem.fromJson(i)).toList()
      : [];
  bool _saving = false;
  bool _exporting = false;

  bool get _isEditing => widget.existingList != null;

  @override
  void initState() {
    super.initState();
    final existingProvince = widget.existingList?['province'];
    if (existingProvince != null && kTurkishProvinces.contains(existingProvince)) {
      _province = existingProvince;
    }
    _district = widget.existingList?['district'];
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_BomItem()));
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    // ÖNEMLİ DÜZELTME: "kaydet dediğimde hiçbir yerde kaydetmiyor" —
    // asıl neden, hata yakalama (catch) hiç olmamasıydı. Bir hata
    // (örn. boş başlık, ağ sorunu, backend hatası) sessizce yutuluyordu,
    // kullanıcıya hiçbir şey gösterilmiyordu. Artık hem başlık boşsa
    // önceden uyarılıyor hem de gerçek hata mesajı gösteriliyor.
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir liste başlığı yazın.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = {
        'title': title,
        'items': _items.map((i) => i.toJson()).toList(),
        'description': _descriptionController.text.trim(),
        'province': _province,
        'district': _district,
      };
      if (_isEditing) {
        await _dio.patch('/bom-lists/${widget.existingList['id']}', data: payload);
      } else {
        await _dio.post('/bom-lists', data: payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      String message = 'Kaydedilemedi, tekrar deneyin.';
      if (e is DioException) {
        final serverMessage = e.response?.data?['message'];
        if (serverMessage is String && serverMessage.isNotEmpty) {
          message = serverMessage;
        } else if (serverMessage is List && serverMessage.isNotEmpty) {
          message = serverMessage.join(', ');
        } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
          message = 'Bağlantı zaman aşımına uğradı, tekrar deneyin.';
        } else if (e.response == null) {
          message = 'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportPdf({required bool andShare}) async {
    setState(() => _exporting = true);
    try {
      // ÖNEMLİ: Türkçe karakterlerin (ç, ğ, ı, ö, ş, ü) PDF'te sembol
      // olarak görünmesinin kesin sebebi buydu — varsayılan yazı tipi
      // bu karakterleri desteklemiyordu. Artık DejaVu Sans (tam Unicode
      // destekli) kullanılıyor.
      await TurkishPdfFonts.ensureLoaded();
      final doc = pw.Document(theme: TurkishPdfFonts.theme());
      final location = [_district, _province].where((s) => s != null && s.isNotEmpty).join(', ');

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('ENTPA Mühendislik Hizmeti', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  pw.SizedBox(height: 4),
                  pw.Text(_titleController.text, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(DateTime.now().toString().substring(0, 16), style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                  if (location.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Row(children: [
                      pw.Text('Konum: ', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                      pw.Text(location, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ]),
                  ],
                  if (_descriptionController.text.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Text(_descriptionController.text, style: const pw.TextStyle(fontSize: 10.5)),
                  ],
                  pw.SizedBox(height: 24),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    columnWidths: {0: const pw.FlexColumnWidth(4), 1: const pw.FlexColumnWidth(1.5), 2: const pw.FlexColumnWidth(1.5)},
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Malzeme', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Miktar', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Birim', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                      ..._items.map((item) => pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item.nameController.text)),
                              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item.quantityController.text)),
                              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item.unitController.text)),
                            ],
                          )),
                    ],
                  ),
                  pw.SizedBox(height: 32),
                  pw.Divider(color: PdfColors.grey300),
                  pw.Text(
                    'Bu liste Bayi Teknik Destek uygulaması tarafından otomatik oluşturulmuştur.',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey400),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final bytes = await doc.save();
      final dir = await getTemporaryDirectory();
      final safeTitle = _titleController.text.replaceAll(RegExp(r'[^\w\s-]'), '');
      final file = File('${dir.path}/$safeTitle-${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes);

      if (andShare) {
        await DocumentPdfExporter.share(file);
      } else {
        await DocumentPdfExporter.view(file);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pdfMenu = _exporting
        ? const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        : PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'view') _exportPdf(andShare: false);
              if (v == 'share') _exportPdf(andShare: true);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'view', child: Text('PDF Görüntüle')),
              const PopupMenuItem(value: 'share', child: Text('PDF Paylaş')),
            ],
            icon: const Icon(Icons.picture_as_pdf_outlined),
          );

    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        navigationBar: CupertinoNavigationBar(
          backgroundColor: const Color(0xFFFFFFFF),
          border: null,
          middle: Text(_isEditing ? 'Malzeme Listesi' : 'Yeni Malzeme Listesi', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          trailing: _items.isNotEmpty ? pdfMenu : null,
        ),
        child: SafeArea(child: _buildBody()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: Text(_isEditing ? 'Malzeme Listesi' : 'Yeni Malzeme Listesi'),
        actions: [if (_items.isNotEmpty) pdfMenu],
      ),
      // ÖNEMLİ DÜZELTME: "Oluştur kısmı sayfanın en altında kalıyor,
      // görünmüyor" — Android tarafında SafeArea hiç yoktu (sadece iOS
      // tarafında vardı), edge-to-edge modu açıkken alttaki sabit
      // buton sistem gezinme çubuğunun arkasında kalıyordu.
      body: SafeArea(child: _buildBody()),
    );
  }

  // ============================================================
  // TABLO/DEFTER TARZI — kart bazlı yapıdan tamamen vazgeçildi.
  // Kullanıcı isteği: "bu tasarımı asla kullanma başka bir tasarım
  // bul" — malzeme listesi artık gerçek bir defter/tablo gibi:
  // kutu/gölge yok, sütun başlıkları var, satırlar ince çizgiyle
  // ayrılıyor.
  // ============================================================
  // ============================================================
  // DÜZ DOLGULU (FLAT) KART TASARIMI — kullanıcı isteği: "kart
  // istiyorum ama tasarım farklı/değişik/sade olmalı." Önceki iki
  // denemeden (gölgeli beyaz kart + tablo/defter) farklı olarak,
  // burada HİÇ gölge/kenarlık kullanılmıyor — sadece açık gri düz
  // dolgu rengiyle ayrılan, tamamen düz (flat) kartlar.
  // ============================================================
  // ============================================================
  // TEK BÜYÜK "BELGE" KARTI — kullanıcı isteği sonrası dördüncü ve
  // farklı bir yaklaşım: artık her malzeme kendi kutusunda değil,
  // TÜM form (başlık + malzemeler) TEK premium beyaz yüzeyde, ince
  // ayraç çizgileriyle bölümlere ayrılmış tek bir "belge" gibi.
  // ============================================================
  // ============================================================
  // Uygulamanın kendi kanıtlanmış StandardCard deseni (Randevu Al,
  // Teknik Destek, Bayi Ziyaretleri gibi ekranlarda sorunsuz
  // çalışıyor) — burada da aynısı kullanılıyor.
  // ============================================================
  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              StandardCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy),
                      decoration: const InputDecoration(labelText: 'Liste Başlığı', border: InputBorder.none, isDense: true),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _descriptionController,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: const InputDecoration(labelText: 'Açıklama (opsiyonel)', border: InputBorder.none, isDense: true),
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 18, color: Colors.grey.shade400),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ProvinceDistrictPicker(
                            province: _province,
                            district: _district,
                            onProvinceChanged: (v) => setState(() => _province = v),
                            onDistrictChanged: (v) => setState(() => _district = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_items.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('${_items.length} MALZEME', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 0.4)),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              ...List.generate(_items.length, (index) {
                final item = _items[index];
                return Container(
                  key: ValueKey(item.id),
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: StandardCard(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        Text('${index + 1}', style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w700)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextField(
                            controller: item.nameController,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.navy),
                            decoration: const InputDecoration(hintText: 'Malzeme adı', isDense: true, border: InputBorder.none),
                          ),
                        ),
                        // Kullanıcı isteği: "adet sayı çıkmıyor... + ve -
                        // koyulmalı" — görünür renkli, +/- butonlu bir
                        // adet ayarlayıcıya çevrildi.
                        _QuantityStepper(controller: item.quantityController),
                        const SizedBox(width: 6),
                        // Kullanıcı isteği: "birim seçilmeli adet mt" —
                        // serbest metin yerine dokununca açılan bir
                        // seçim menüsü.
                        _UnitPicker(controller: item.unitController),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                          onPressed: () => _removeItem(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text('Henüz malzeme eklenmedi.', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, -3))],
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addItem,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Malzeme Ekle'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isEditing ? 'Değişiklikleri Kaydet' : 'Listeyi Kaydet', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Görünür, renkli "- rakam +" adet ayarlayıcı.
class _QuantityStepper extends StatefulWidget {
  final TextEditingController controller;
  const _QuantityStepper({required this.controller});

  @override
  State<_QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<_QuantityStepper> {
  void _change(int delta) {
    final current = int.tryParse(widget.controller.text) ?? 1;
    final next = (current + delta).clamp(1, 9999);
    widget.controller.text = '$next';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
            onTap: () => _change(-1),
            child: const Padding(padding: EdgeInsets.all(7), child: Icon(Icons.remove, size: 15, color: Colors.black87)),
          ),
          // Kullanıcı isteği: "buraya sayı yazılmalı" — artık +/- ile
          // değiştirilebildiği gibi doğrudan da yazılabiliyor.
          SizedBox(
            width: 46,
            child: TextField(
              controller: widget.controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black),
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 8)),
            ),
          ),
          InkWell(
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
            onTap: () => _change(1),
            child: const Padding(padding: EdgeInsets.all(7), child: Icon(Icons.add, size: 15, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}

/// Yaygın birimler arasından dokununca seçim yapılan birim seçici —
/// serbest metin yerine tutarlı, hatasız veri girişi sağlar.
class _UnitPicker extends StatefulWidget {
  final TextEditingController controller;
  const _UnitPicker({required this.controller});

  @override
  State<_UnitPicker> createState() => _UnitPickerState();
}

class _UnitPickerState extends State<_UnitPicker> {
  static const _units = ['adet', 'mt', 'kg', 'm²', 'paket', 'kutu', 'rulo', 'takım'];

  Future<void> _pick() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: _units
              .map((u) => ListTile(
                    title: Text(u),
                    trailing: widget.controller.text == u ? const Icon(Icons.check, size: 18, color: AppColors.brand) : null,
                    onTap: () => Navigator.pop(context, u),
                  ))
              .toList(),
        ),
      ),
    );
    if (selected != null) setState(() => widget.controller.text = selected);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _pick,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, value, _) => Text(
                value.text.isEmpty ? 'adet' : value.text,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
