import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';

/// PDF'lerde önceden hiç özel bir yazı tipi belirtilmiyordu — bu yüzden
/// varsayılan (Helvetica tabanlı) yazı tipi kullanılıyordu, bu da Türkçe
/// karaktersiz (ç, ğ, ı, ö, ş, ü) glifleri desteklemediği için harfler
/// PDF çıktısında sembol/kutucuk olarak görünüyordu. Artık Türkçe dahil
/// geniş bir Unicode aralığını destekleyen DejaVu Sans yazı tipi
/// projeye gömülüp tüm PDF'lerde kullanılıyor.
class TurkishPdfFonts {
  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<void> ensureLoaded() async {
    if (_regular != null && _bold != null) return;
    final regularData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final boldData = await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf');
    _regular = pw.Font.ttf(regularData);
    _bold = pw.Font.ttf(boldData);
  }

  static pw.ThemeData theme() {
    return pw.ThemeData.withFont(base: _regular, bold: _bold);
  }
}

/// Devreye Alma raporu, Bakım kaydı, Sertifika gibi profesyonel
/// dokümanların PDF'e dönüştürülmesi için ortak, tek bir yer — hepsinde
/// aynı üst bilgi (tarih/saat, bayi bilgisi), aynı görünüm, ve isteğe
/// bağlı olarak imza görselinin gömülmesi burada standartlaştırılıyor.
class DocumentPdfExporter {
  /// PDF'i oluşturup cihaza kaydeder, dosya yolunu döner (görüntüleme/
  /// paylaşma bu yoldan yapılır).
  static Future<File> build({
    required String documentTitle,
    required String dealerName,
    required String dealerCompany,
    List<({String label, String value})> infoRows = const [],
    List<({String label, bool checked})>? checklist,
    String? notes,
    Uint8List? signatureBytes,
    String? customerName,
  }) async {
    await TurkishPdfFonts.ensureLoaded();
    final doc = pw.Document(theme: TurkishPdfFonts.theme());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) => [
          pw.Text(
            'ENTPA Mühendislik Hizmeti',
            style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            documentTitle,
            style: pw.TextStyle(fontSize: 21, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoLine(
                  'Tarih / Saat',
                  DateTime.now().toString().substring(0, 16),
                ),
                _infoLine('Bayi', '$dealerName ($dealerCompany)'),
                if (customerName != null && customerName.isNotEmpty)
                  _infoLine('Müşteri', customerName),
                ...infoRows.map((r) => _infoLine(r.label, r.value)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          if (checklist != null) ...[
            pw.Text(
              'Kontrol Listesi',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(5),
                1: const pw.FlexColumnWidth(1),
              },
              children: checklist
                  .map(
                    (item) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            item.label,
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            item.checked ? 'Evet' : 'Hayır',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: item.checked
                                  ? PdfColors.green700
                                  : PdfColors.red700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 16),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            pw.Text(
              'Notlar / Açıklama',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(notes, style: const pw.TextStyle(fontSize: 10.5)),
            pw.SizedBox(height: 16),
          ],
          if (signatureBytes != null) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Müşteri İmzası',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Image(
                pw.MemoryImage(signatureBytes),
                width: 200,
                height: 100,
                fit: pw.BoxFit.contain,
              ),
            ),
          ],
          pw.SizedBox(height: 30),
          pw.Divider(color: PdfColors.grey300),
          pw.Text(
            'Bu doküman Bayi Teknik Destek uygulaması tarafından otomatik oluşturulmuştur.',
            style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey400),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final safeTitle = documentTitle.replaceAll(RegExp(r'[^\w\s-]'), '');
    final file = File(
      '${dir.path}/$safeTitle-${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes);
    return file;
  }

  static pw.Widget _infoLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> view(File file) => OpenFilex.open(file.path);

  static Future<void> share(File file) => Share.shareXFiles([XFile(file.path)]);

  /// Backend'den bir imzanın imzalı (signed) URL'sini alıp bayt olarak
  /// indirir — PDF'e gömmek için.
  static Future<Uint8List?> downloadSignature(
    Dio dio,
    String signedUrlEndpoint,
  ) async {
    try {
      final res = await dio.get(signedUrlEndpoint);
      final url = res.data as String?;
      if (url == null) return null;
      final response = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data!);
    } catch (_) {
      return null;
    }
  }
}
