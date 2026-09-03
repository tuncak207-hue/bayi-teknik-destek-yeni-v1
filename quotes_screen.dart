import 'dart:io';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_components.dart';
import '../../core/widgets/design_system.dart';
import '../../core/pdf/document_pdf_exporter.dart';
import '../../core/widgets/province_district_picker.dart';
import '../../core/data/turkey_locations.dart';

/// Teklif Al — bayi, admin'in yönettiği fiyat/malzeme kataloğundan seçim
/// yaparak müşteri için otomatik hesaplanan bir teklif oluşturur.
class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  final Dio _dio = ApiClient().dio;
  List<dynamic> _quotes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _dio.get('/quotes');
    setState(() {
      _quotes = res.data;
      _loading = false;
    });
  }

  Future<void> _openBuilder({dynamic existingQuote}) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _QuoteBuilderScreen(existingQuote: existingQuote)),
    );
    if (created == true) _load();
  }

  Future<void> _openPriceListPdf() async {
    try {
      final res = await _dio.get('/quotes/price-list-document');
      final url = res.data as String?;
      if (url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.noPriceListPdfYet)),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/fiyat-listesi.pdf';
      await Dio().download(url, path);
      await DocumentPdfExporter.view(File(path));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.priceListOpenFailed)));
      }
    }
  }

  Future<void> _delete(dynamic quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteQuote),
        content: Text('"${quote['title']}" silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(AppLocalizations.of(context)!.delete, style: TextStyle(color: AppColors.navy))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _dio.delete('/quotes/${quote['id']}');
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
      floatingActionButton: StandardFab(label: AppLocalizations.of(context)!.screenNewQuote, onPressed: () => _openBuilder()),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Teklif Al',
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
                      '${_quotes.length}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'Fiyat Listesi PDF',
                    onPressed: _openPriceListPdf,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _quotes.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          children: [
                            const SizedBox(height: 72),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                              child: StandardCard(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
                                child: AppEmptyState(
                                  icon: Icons.request_quote_outlined,
                                  title: AppLocalizations.of(context)!.emptyQuotes,
                                  description: AppLocalizations.of(context)!.quotesEmptyHint,
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
                          itemCount: _quotes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                          itemBuilder: (context, index) {
                      final q = _quotes[index];
                      final items = (q['items'] as List?) ?? [];
                      return StandardCard(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _QuoteDetailScreen(quote: q))),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyLight]),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: const Icon(Icons.request_quote_outlined, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(q['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.navy)),
                                  const SizedBox(height: 4),
                                  CardFooterMeta(
                                    icon: Icons.person_outline,
                                    label: '${q['customerName'] ?? 'Müşteri belirtilmedi'} · ${items.length} kalem · ${_formatDate(q['createdAt'])}',
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${(q['totalAmount'] as num).toStringAsFixed(0)} €', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.brand, fontSize: 14)),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                                      onPressed: () => _openBuilder(existingQuote: q),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      tooltip: 'Düzenle',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                      onPressed: () => _delete(q),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      tooltip: 'Sil',
                                    ),
                                  ],
                                ),
                              ],
                            ),
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

class _CartItem {
  final String priceListItemId;
  final String name;
  final String unit;
  final double unitPrice;
  int quantity;
  // Miktarın elle girilebilmesi için — kullanıcı isteği: "adet sayısı
  // elle girilebilmeli + ve - ile azaltılıp arttırılabilmeli".
  late final TextEditingController quantityController = TextEditingController(text: quantity.toString());

  _CartItem({required this.priceListItemId, required this.name, required this.unit, required this.unitPrice, this.quantity = 1});

  double get subtotal => unitPrice * quantity;

  void syncControllerText() {
    quantityController.text = quantity.toString();
    quantityController.selection = TextSelection.collapsed(offset: quantityController.text.length);
  }
}

class _QuoteBuilderScreen extends StatefulWidget {
  final dynamic existingQuote;
  const _QuoteBuilderScreen({this.existingQuote});

  @override
  State<_QuoteBuilderScreen> createState() => _QuoteBuilderScreenState();
}

class _QuoteBuilderScreenState extends State<_QuoteBuilderScreen> {
  final Dio _dio = ApiClient().dio;
  // Kullanıcı isteği: "teklif başlığı içindeki yazı silinebilir olmalı,
  // üzerine tıklayıp bir şey yazdığımda silinmeli" — önceden yeni teklif
  // açılırken "Yangın Sistemi Teklifi" GERÇEK bir metin olarak alana
  // yerleşiyordu (ipucu değil), kullanıcı önce elle silmek zorunda
  // kalıyordu. Artık yeni teklifte alan BOŞ başlıyor, varsayılan başlık
  // sadece soluk bir İPUCU (hint) olarak görünüyor — yazmaya başlayınca
  // otomatik kayboluyor. Var olan bir teklifi düzenlerken gerçek başlık
  // yine olduğu gibi gösteriliyor.
  late final _titleController = TextEditingController(text: widget.existingQuote?['title'] ?? '');
  late final _customerNameController = TextEditingController(text: widget.existingQuote?['customerName'] ?? '');
  late final _customerPhoneController = TextEditingController(text: widget.existingQuote?['customerPhone'] ?? '');
  String? _district;
  String? _province;
  List<dynamic> _catalog = [];
  final _searchController = TextEditingController();
  final Map<String, _CartItem> _cart = {};
  bool _loading = true;
  bool _submitting = false;

  bool get _isEditing => widget.existingQuote != null;

  @override
  void initState() {
    super.initState();
    _district = widget.existingQuote?['district'];
    _loadCatalog();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final res = await _dio.get('/quotes/price-list');
    setState(() {
      _catalog = res.data;
      _loading = false;
      // Düzenleme modundaysa, mevcut teklifteki kalemleri katalogla
      // eşleştirip sepete önceden dolduruyoruz — kullanıcı sıfırdan
      // seçmek zorunda kalmıyor.
      if (_isEditing) {
        final existingItems = (widget.existingQuote['items'] as List?) ?? [];
        for (final existing in existingItems) {
          final match = _catalog.firstWhere(
            (c) => c['name'] == existing['name'] && c['unit'] == existing['unit'],
            orElse: () => null,
          );
          if (match != null) {
            _cart[match['id']] = _CartItem(
              priceListItemId: match['id'],
              name: match['name'],
              unit: match['unit'],
              unitPrice: (match['unitPrice'] as num).toDouble(),
              quantity: (existing['quantity'] as num).toInt(),
            );
          }
        }
        final existingProvince = widget.existingQuote['province'];
        if (existingProvince != null && kTurkeyProvinceDistricts.containsKey(existingProvince)) {
          _province = existingProvince;
        }
      }
    });
  }

  void _toggleItem(dynamic priceItem) {
    setState(() {
      final id = priceItem['id'];
      if (_cart.containsKey(id)) {
        _cart.remove(id);
      } else {
        _cart[id] = _CartItem(
          priceListItemId: id,
          name: priceItem['name'],
          unit: priceItem['unit'],
          unitPrice: (priceItem['unitPrice'] as num).toDouble(),
        );
      }
    });
  }

  double get _total => _cart.values.fold(0, (sum, i) => sum + i.subtotal);

  Future<void> _submit() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectAtLeastOneItem)));
      return;
    }
    setState(() => _submitting = true);
    try {
      final payload = {
        'title': _titleController.text.trim().isEmpty ? 'Yangın Sistemi Teklifi' : _titleController.text.trim(),
        'customerName': _customerNameController.text.trim(),
        'customerPhone': _customerPhoneController.text.trim(),
        'province': _province,
        'district': _district,
        'items': _cart.values.map((i) => {'priceListItemId': i.priceListItemId, 'quantity': i.quantity}).toList(),
      };
      if (_isEditing) {
        await _dio.put('/quotes/${widget.existingQuote['id']}', data: payload);
      } else {
        await _dio.post('/quotes', data: payload);
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Map<String, List<dynamic>> get _groupedCatalog {
    // Kullanıcı isteği: "arama butonuda koy ürünü ordan arayıp seçebilsin
    // filtreleme şart" — ad, kod ve markaya göre filtreleniyor.
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _catalog
        : _catalog.where((item) {
            final name = (item['name'] ?? '').toString().toLowerCase();
            final code = (item['code'] ?? '').toString().toLowerCase();
            final brand = (item['brand'] ?? '').toString().toLowerCase();
            return name.contains(query) || code.contains(query) || brand.contains(query);
          }).toList();

    final map = <String, List<dynamic>>{};
    for (final item in filtered) {
      final category = (item['category'] as String?)?.trim();
      final key = (category == null || category.isEmpty) ? 'Genel' : category;
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        navigationBar: CupertinoNavigationBar(
          backgroundColor: const Color(0xFFFFFFFF),
          border: null,
          middle: Text(_isEditing ? 'Teklifi Düzenle' : 'Yeni Teklif', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
        child: SafeArea(child: _buildBody()),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppPageHeader(title: _isEditing ? AppLocalizations.of(context)!.screenEditQuote : AppLocalizations.of(context)!.screenNewQuote),
      // ÖNEMLİ DÜZELTME: "Toplam kısmı sayfanın altında kalıyor,
      // görünmüyor" — Android tarafında SafeArea hiç yoktu (sadece iOS
      // tarafında vardı), edge-to-edge modu açıkken içerik sistem
      // gezinme çubuğunun arkasında kalıyordu. Eklendi.
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    return _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: AppShadows.subtle,
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _titleController,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy),
                              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.quoteTitle, hintText: 'Yangın Sistemi Teklifi', border: InputBorder.none, isDense: true),
                            ),
                            const Divider(height: 16),
                            TextField(
                              controller: _customerNameController,
                              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.customerName, border: InputBorder.none, isDense: true),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _customerPhoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.customerPhoneOptional, border: InputBorder.none, isDense: true),
                            ),
                            const Divider(height: 16),
                            ProvinceDistrictPicker(
                              province: _province,
                              district: _district,
                              onProvinceChanged: (v) => setState(() => _province = v),
                              onDistrictChanged: (v) => setState(() => _district = v),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: AppSpacing.md),
                      if (_catalog.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Text(AppLocalizations.of(context)!.noPriceListYet, style: TextStyle(color: Colors.grey.shade500), textAlign: TextAlign.center),
                        )
                      else ...[
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            boxShadow: AppShadows.subtle,
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)!.searchProductHint,
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () => setState(() => _searchController.clear()),
                                    )
                                  : null,
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (_groupedCatalog.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Text('"${_searchController.text}" ile eşleşen ürün bulunamadı.', style: TextStyle(color: Colors.grey.shade500), textAlign: TextAlign.center),
                          ),
                        ..._groupedCatalog.entries.map((entry) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
                                  child: Text(entry.key.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 0.4)),
                                ),
                                ...entry.value.map((item) {
                                  final selected = _cart.containsKey(item['id']);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      border: selected ? Border.all(color: AppColors.brand.withValues(alpha: 0.4), width: 1.5) : null,
                                      boxShadow: AppShadows.subtle,
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                        onTap: () => _toggleItem(item),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
                                          child: Row(
                                            children: [
                                              Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? AppColors.brand : Colors.grey.shade300, size: 20),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                                    Text('${(item['unitPrice'] as num).toStringAsFixed(2)} € / ${item['unit']}', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                                                  ],
                                                ),
                                              ),
                                              if (selected)
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                                                      onPressed: () => setState(() {
                                                        if (_cart[item['id']]!.quantity > 1) {
                                                          _cart[item['id']]!.quantity--;
                                                          _cart[item['id']]!.syncControllerText();
                                                        }
                                                      }),
                                                    ),
                                                    SizedBox(
                                                      width: 40,
                                                      child: TextField(
                                                        controller: _cart[item['id']]!.quantityController,
                                                        keyboardType: TextInputType.number,
                                                        textAlign: TextAlign.center,
                                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                                        decoration: const InputDecoration(
                                                          isDense: true,
                                                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                                                          border: OutlineInputBorder(),
                                                        ),
                                                        onChanged: (value) {
                                                          final parsed = int.tryParse(value);
                                                          if (parsed != null && parsed >= 1) {
                                                            setState(() => _cart[item['id']]!.quantity = parsed);
                                                          }
                                                        },
                                                        onSubmitted: (value) {
                                                          // Boş bırakılır ya da geçersiz girilirse 1'e sıfırlanır.
                                                          final parsed = int.tryParse(value);
                                                          if (parsed == null || parsed < 1) {
                                                            setState(() {
                                                              _cart[item['id']]!.quantity = 1;
                                                              _cart[item['id']]!.syncControllerText();
                                                            });
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.add_circle_outline, size: 20),
                                                      onPressed: () => setState(() {
                                                        _cart[item['id']]!.quantity++;
                                                        _cart[item['id']]!.syncControllerText();
                                                      }),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            )),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))]),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(AppLocalizations.of(context)!.total, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          Text('${_total.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.brand)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: _submitting
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_isEditing ? 'Değişiklikleri Kaydet' : 'Teklifi Oluştur', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
  }
}

class _QuoteDetailScreen extends StatefulWidget {
  final dynamic quote;
  const _QuoteDetailScreen({required this.quote});

  @override
  State<_QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<_QuoteDetailScreen> {
  bool _exporting = false;

  Future<void> _exportPdf({required bool andShare}) async {
    setState(() => _exporting = true);
    try {
      await TurkishPdfFonts.ensureLoaded();
      final doc = pw.Document(theme: TurkishPdfFonts.theme());
      final q = widget.quote;
      final items = (q['items'] as List);
      final location = [q['district'], q['province']].where((s) => s != null && s.toString().isNotEmpty).join(', ');

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
                  pw.Text(q['title'] ?? 'Teklif', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(DateTime.now().toString().substring(0, 16), style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                  pw.SizedBox(height: 12),
                  if ((q['customerName'] ?? '').toString().isNotEmpty)
                    pw.Text('Müşteri: ${q['customerName']}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  if (location.isNotEmpty) pw.Text('Konum: $location', style: const pw.TextStyle(fontSize: 10.5)),
                  pw.SizedBox(height: 20),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    columnWidths: {0: const pw.FlexColumnWidth(4), 1: const pw.FlexColumnWidth(1.5), 2: const pw.FlexColumnWidth(1.5), 3: const pw.FlexColumnWidth(2)},
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(AppLocalizations.of(context)!.material, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(AppLocalizations.of(context)!.quantity, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(AppLocalizations.of(context)!.unitPrice, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(AppLocalizations.of(context)!.amount, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                      ...items.map((item) => pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${item['name']}')),
                              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${item['quantity']} ${item['unit']}')),
                              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${(item['unitPrice'] as num).toStringAsFixed(2)} €')),
                              pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${(item['subtotal'] as num).toStringAsFixed(2)} €')),
                            ],
                          )),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text('GENEL TOPLAM: ${(q['totalAmount'] as num).toStringAsFixed(2)} €', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(height: 32),
                  pw.Divider(color: PdfColors.grey300),
                  pw.Text(
                    'Bu teklif Bayi Teknik Destek uygulaması tarafından otomatik oluşturulmuştur.',
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
      final safeTitle = (q['title'] ?? 'Teklif').toString().replaceAll(RegExp(r'[^\w\s-]'), '');
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
    final q = widget.quote;
    final items = (q['items'] as List);
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppPageHeader(
        title: AppLocalizations.of(context)!.screenQuoteDetail,
        actions: [
          if (_exporting)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'view') _exportPdf(andShare: false);
                if (v == 'share') _exportPdf(andShare: true);
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'view', child: Text(AppLocalizations.of(context)!.viewPdf)),
                PopupMenuItem(value: 'share', child: Text(AppLocalizations.of(context)!.sharePdf)),
              ],
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadows.subtle),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q['title'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.navy)),
                if ((q['customerName'] ?? '').toString().isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(AppLocalizations.of(context)!.customerLabel(q['customerName']), style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                ],
                const Divider(height: 20),
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text('${item['name']} (${item['quantity']} ${item['unit']})', style: const TextStyle(fontSize: 12.5))),
                          Text('${(item['subtotal'] as num).toStringAsFixed(2)} €', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppLocalizations.of(context)!.grandTotal, style: TextStyle(fontWeight: FontWeight.w800)),
                    Text('${(q['totalAmount'] as num).toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.brand)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
